import {
  BadGatewayException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { SearchQueryDto } from '../dtos/search-query.dto';
import { DependencyError } from '../errors/dependency.error';
import {
  CatalogPort,
  SubjectAcademicContext,
} from '../ports/catalog.port';
import {
  MaterialCandidate,
  MaterialPage,
  MaterialPageQuery,
  MaterialPort,
} from '../ports/material.port';
import { SearchService } from './search.service';

class CatalogStub extends CatalogPort {
  response: SubjectAcademicContext[] = [];
  error: Error | null = null;
  calls = 0;

  async getAcademicContext(): Promise<SubjectAcademicContext[]> {
    this.calls += 1;

    if (this.error) {
      throw this.error;
    }

    return this.response;
  }
}

class MaterialStub extends MaterialPort {
  response: MaterialPage = { items: [], page: 1, pageSize: 20, total: 0 };
  error: Error | null = null;
  calls: MaterialPageQuery[] = [];

  async findCandidates(query: MaterialPageQuery): Promise<MaterialPage> {
    this.calls.push(query);

    if (this.error) {
      throw this.error;
    }

    return this.response;
  }
}

const catalogSubject = (): SubjectAcademicContext => ({
  subjectId: 'subject-1',
  subjectName: 'Estructuras de Datos',
  subjectCode: 'INF-201',
  semester: 3,
  careerId: 'career-1',
  careerName: 'Ingeniería Civil Informática',
  universityId: 'university-1',
  universityName: 'Universidad Católica de Temuco',
  professors: [{ id: 'professor-1', name: 'Ada Lovelace' }],
});

const materialCandidate = (
  overrides: Partial<MaterialCandidate> = {},
): MaterialCandidate => ({
  id: 'material-1',
  title: 'Apunte de listas enlazadas',
  description: 'Resumen de la unidad 2',
  materialType: 'APUNTE',
  academicYear: 2026,
  verified: true,
  subjectId: 'subject-1',
  careerId: 'career-1',
  universityId: 'university-1',
  professorId: 'professor-1',
  createdAt: '2026-10-01T00:00:00.000Z',
  updatedAt: '2026-10-02T00:00:00.000Z',
  ...overrides,
});

const searchQuery = (
  overrides: Partial<SearchQueryDto> = {},
): SearchQueryDto => Object.assign(new SearchQueryDto(), overrides);

describe('SearchService', () => {
  let catalog: CatalogStub;
  let material: MaterialStub;
  let service: SearchService;

  beforeEach(() => {
    catalog = new CatalogStub();
    material = new MaterialStub();
    service = new SearchService(catalog, material);
    catalog.response = [catalogSubject()];
    material.response = {
      items: [materialCandidate()],
      page: 1,
      pageSize: 20,
      total: 1,
    };
  });

  it('compone los materiales de Material con el contexto académico de Catalog', async () => {
    const response = await service.search(searchQuery({ q: 'listas' }));

    expect(response.query).toBe('listas');
    expect(response.page).toBe(1);
    expect(response.pageSize).toBe(20);
    expect(response.total).toBe(1);
    expect(response.results).toHaveLength(1);
    expect(response.results[0]).toMatchObject({
      id: 'material-1',
      title: 'Apunte de listas enlazadas',
      subjectName: 'Estructuras de Datos',
      careerName: 'Ingeniería Civil Informática',
      universityName: 'Universidad Católica de Temuco',
    });
    expect(response.context).toEqual([catalogSubject()]);
  });

  it('consulta ambos servicios con la paginación solicitada', async () => {
    await service.search(searchQuery({ page: 2, pageSize: 5 }));

    expect(catalog.calls).toBe(1);
    expect(material.calls).toEqual([{ page: 2, pageSize: 5 }]);
  });

  it('conserva la paginación informada por Material', async () => {
    material.response = { items: [], page: 4, pageSize: 10, total: 35 };

    const response = await service.search(
      searchQuery({ page: 4, pageSize: 10 }),
    );

    expect(response).toMatchObject({ page: 4, pageSize: 10, total: 35 });
  });

  it('deduplica el contexto académico por asignatura', async () => {
    material.response = {
      items: [materialCandidate(), materialCandidate({ id: 'material-2' })],
      page: 1,
      pageSize: 20,
      total: 2,
    };

    const response = await service.search(searchQuery());

    expect(response.results).toHaveLength(2);
    expect(response.context).toHaveLength(1);
  });

  it('deja el contexto en null cuando Catalog no conoce la asignatura', async () => {
    material.response = {
      items: [materialCandidate({ subjectId: 'subject-desconocida' })],
      page: 1,
      pageSize: 20,
      total: 1,
    };

    const response = await service.search(searchQuery());

    expect(response.results[0]).toMatchObject({
      subjectId: 'subject-desconocida',
      subjectName: null,
      careerName: null,
      universityName: null,
    });
    expect(response.context).toEqual([]);
  });

  it('responde 503 controlado cuando Catalog no está disponible', async () => {
    catalog.error = new DependencyError(
      'Catalog Service',
      'unavailable',
      'Catalog Service no está disponible',
    );

    await expect(service.search(searchQuery())).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('responde 503 controlado cuando Material no responde a tiempo', async () => {
    material.error = new DependencyError(
      'Material Service',
      'timeout',
      'Material Service no respondió dentro del tiempo esperado',
    );

    await expect(service.search(searchQuery())).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('responde 502 controlado cuando un servicio devuelve un formato inválido', async () => {
    catalog.error = new DependencyError(
      'Catalog Service',
      'invalid-response',
      'Catalog Service devolvió un formato inesperado',
    );

    await expect(service.search(searchQuery())).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it('nombra el servicio dependiente en el mensaje de error', async () => {
    catalog.error = new DependencyError(
      'Catalog Service',
      'upstream-error',
      'Catalog Service respondió con estado 500',
    );

    await expect(service.search(searchQuery())).rejects.toMatchObject({
      message: 'Catalog Service respondió con estado 500',
    });
  });

  it('responde 503 ante un error inesperado', async () => {
    material.error = new Error('boom');

    await expect(service.search(searchQuery())).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});
