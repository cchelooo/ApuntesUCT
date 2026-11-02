import { BadGatewayException, ServiceUnavailableException } from '@nestjs/common';
import { SearchQueryDto } from '../dtos/search-query.dto';
import { CatalogPort, SubjectAcademicContext } from '../ports/catalog.port';
import {
  MaterialCandidate,
  MaterialPage,
  MaterialPageQuery,
  MaterialPort,
} from '../ports/material.port';
import { SearchService } from './search.service';

class CatalogStub extends CatalogPort {
  response: SubjectAcademicContext[] = [];
  getAcademicContext(): Promise<SubjectAcademicContext[]> {
    return Promise.resolve(this.response);
  }
}
class MaterialStub extends MaterialPort {
  candidates: MaterialCandidate[] = [];
  calls: MaterialPageQuery[] = [];
  findCandidates(query: MaterialPageQuery): Promise<MaterialPage> {
    this.calls.push(query);
    const start = (query.page - 1) * query.pageSize;
    return Promise.resolve({
      items: this.candidates.slice(start, start + query.pageSize),
      page: query.page,
      pageSize: query.pageSize,
      total: this.candidates.length,
    });
  }
}
function candidate(id: string, overrides: Partial<MaterialCandidate> = {}): MaterialCandidate {
  return {
    id,
    title: 'Material de ejemplo',
    description: null,
    materialType: 'DOCUMENT',
    academicYear: 2026,
    verified: false,
    subjectId: 'subject-1',
    careerId: 'career-1',
    universityId: 'university-1',
    professorId: null,
    // Fechas distintas hacen explícito el orden de estos fixtures: 1, 2, 3...
    // Los empates reales se verifican en search-filters.service.spec.ts.
    createdAt: new Date(Date.UTC(2026, 9, 1) - Number(id) * 1000).toISOString(),
    updatedAt: '2026-10-01T00:00:00.000Z',
    ...overrides,
  };
}
const query = (overrides: Partial<SearchQueryDto> = {}): SearchQueryDto =>
  Object.assign(new SearchQueryDto(), overrides);

describe('SearchService: búsqueda textual', () => {
  let catalog: CatalogStub;
  let material: MaterialStub;
  let service: SearchService;
  beforeEach(() => {
    catalog = new CatalogStub();
    material = new MaterialStub();
    service = new SearchService(catalog, material);
  });

  it('encuentra coincidencias en el título', async () => {
    material.candidates = [
      candidate('1', { title: 'Guía de Álgebra' }),
      candidate('2', { title: 'Introducción a programación' }),
    ];
    const response = await service.search(query({ q: 'algebra' }));
    expect(response.query).toBe('algebra');
    expect(response.total).toBe(1);
    expect(response.results.map((item) => item.id)).toEqual(['1']);
  });
  it('encuentra coincidencias en la descripción', async () => {
    material.candidates = [
      candidate('1', {
        title: 'Guía de estudio',
        description: 'Ejercicios de estructuras de datos',
      }),
      candidate('2', { title: 'Otro documento', description: null }),
    ];
    const response = await service.search(query({ q: 'estructuras' }));
    expect(response.total).toBe(1);
    expect(response.results[0].id).toBe('1');
  });
  it('ignora diferencias de mayúsculas y tildes', async () => {
    material.candidates = [candidate('1', { title: 'ÁLGEBRA LINEAL' })];
    const response = await service.search(query({ q: 'álgebra' }));
    expect(response.total).toBe(1);
    expect(response.results[0].title).toBe('ÁLGEBRA LINEAL');
  });
  it('elimina espacios al inicio y al final del texto', async () => {
    material.candidates = [candidate('1', { title: 'Guía de cálculo' })];
    const response = await service.search(query({ q: '  calculo  ' }));
    expect(response.query).toBe('calculo');
    expect(response.total).toBe(1);
  });
  it('trata una consulta con solo espacios como búsqueda sin texto', async () => {
    material.candidates = [candidate('1'), candidate('2'), candidate('3')];
    const response = await service.search(query({ q: '   ', page: 2, pageSize: 1 }));
    expect(response.query).toBeNull();
    expect(response.total).toBe(3);
    expect(response.results.map((item) => item.id)).toEqual(['2']);
    expect(material.calls).toEqual([{ page: 2, pageSize: 1 }]);
  });
  it('devuelve cero resultados si no hay coincidencias', async () => {
    material.candidates = [candidate('1', { title: 'Guía de cálculo' })];
    const response = await service.search(query({ q: 'historia' }));
    expect(response.total).toBe(0);
    expect(response.results).toEqual([]);
    expect(response.context).toEqual([]);
  });
  it('encuentra materiales ubicados en una página posterior de Material', async () => {
    material.candidates = Array.from({ length: 101 }, (_, index) =>
      candidate(String(index + 1), {
        title: index === 100 ? 'Apunte de estructuras' : 'Material sin coincidencia',
      }),
    );
    const response = await service.search(query({ q: 'estructuras' }));
    expect(response.total).toBe(1);
    expect(response.results[0].id).toBe('101');
    expect(material.calls).toEqual([
      { page: 1, pageSize: 100 },
      { page: 2, pageSize: 100 },
    ]);
  });
  it('calcula el total y pagina después de buscar en todos los candidatos', async () => {
    material.candidates = Array.from({ length: 105 }, (_, index) =>
      candidate(String(index + 1), {
        title: index % 20 === 0 ? 'Guía de álgebra' : 'Otro material',
      }),
    );
    const response = await service.search(query({ q: 'algebra', page: 2, pageSize: 2 }));
    expect(response.total).toBe(6);
    expect(response.page).toBe(2);
    expect(response.pageSize).toBe(2);
    expect(response.results.map((item) => item.id)).toEqual(['41', '61']);
  });
  it('devuelve una página vacía si está fuera de los resultados', async () => {
    material.candidates = [candidate('1', { title: 'Álgebra' })];
    const response = await service.search(query({ q: 'algebra', page: 3, pageSize: 2 }));
    expect(response.total).toBe(1);
    expect(response.results).toEqual([]);
  });
  it('rechaza una respuesta con paginación inconsistente', async () => {
    jest
      .spyOn(material, 'findCandidates')
      .mockResolvedValue({ items: [], page: 2, pageSize: 100, total: 0 });
    await expect(service.search(query({ q: 'algebra' }))).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });
  it('rechaza resultados duplicados en páginas distintas', async () => {
    const firstPage = Array.from({ length: 100 }, (_, index) => candidate(String(index + 1)));
    jest
      .spyOn(material, 'findCandidates')
      .mockResolvedValueOnce({ items: firstPage, page: 1, pageSize: 100, total: 101 })
      .mockResolvedValueOnce({ items: [candidate('1')], page: 2, pageSize: 100, total: 101 });
    await expect(service.search(query({ q: 'material' }))).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });
  it('rechaza una búsqueda que supera el límite de candidatos', async () => {
    jest.spyOn(material, 'findCandidates').mockResolvedValue({
      items: Array.from({ length: 100 }, (_, index) => candidate(String(index + 1))),
      page: 1,
      pageSize: 100,
      total: 10001,
    });
    await expect(service.search(query({ q: 'material' }))).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});
