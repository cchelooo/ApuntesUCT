import {
  BadGatewayException,
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { SearchOrder, SearchQueryDto, SearchSortBy } from '../dtos/search-query.dto';
import { SubjectAcademicContext } from '../ports/catalog.port';
import { MaterialCandidate, MaterialPageQuery } from '../ports/material.port';
import { SearchService } from './search.service';

const uuid = (n: number): string => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const U = uuid(1),
  C = uuid(2),
  S = uuid(3),
  P = uuid(4);
const U2 = uuid(11),
  C2 = uuid(12),
  S2 = uuid(13),
  P2 = uuid(14);
const academic = { universityId: U, careerId: C, subjectId: S, professorId: P };
const context = (overrides: Partial<SubjectAcademicContext> = {}): SubjectAcademicContext => ({
  subjectId: S,
  subjectName: 'Álgebra',
  subjectCode: 'MAT',
  semester: 1,
  careerId: C,
  careerName: 'Informática',
  universityId: U,
  universityName: 'Universidad',
  professors: [
    { id: P, name: 'Profesora' },
    { id: P2, name: 'Otro profesor' },
  ],
  ...overrides,
});
const candidate = (n: number, overrides: Partial<MaterialCandidate> = {}): MaterialCandidate => ({
  id: uuid(1000 + n),
  title: 'Guía de álgebra',
  description: null,
  materialType: 'DOCUMENT',
  academicYear: 2026,
  verified: false,
  subjectId: S,
  careerId: C,
  universityId: U,
  professorId: P,
  createdAt: '2026-10-01T00:00:00.000Z',
  updatedAt: '2026-10-02T00:00:00.000Z',
  ...overrides,
});
const query = (overrides: Partial<SearchQueryDto> = {}): SearchQueryDto =>
  Object.assign(new SearchQueryDto(), overrides);

describe('SearchService: filtros y ordenamiento', () => {
  let rows: MaterialCandidate[];
  let contexts: SubjectAcademicContext[];
  const catalog = { getAcademicContext: jest.fn() };
  const material = { findCandidates: jest.fn() };
  let service: SearchService;
  beforeEach(() => {
    jest.resetAllMocks();
    rows = [candidate(1)];
    contexts = [context()];
    catalog.getAcademicContext.mockImplementation(() => Promise.resolve(contexts));
    material.findCandidates.mockImplementation(({ page, pageSize }: MaterialPageQuery) =>
      Promise.resolve({
        items: rows.slice((page - 1) * pageSize, page * pageSize),
        page,
        pageSize,
        total: rows.length,
      }),
    );
    service = new SearchService(catalog, material);
  });

  it.each([
    [SearchOrder.ASC, [1002, 1001]],
    [SearchOrder.DESC, [1001, 1002]],
  ])('ordena títulos distintos en dirección %s', async (order, expected) => {
    rows = [candidate(1, { title: 'Zoología' }), candidate(2, { title: 'Álgebra' })];
    const result = await service.search(query({ sortBy: SearchSortBy.TITLE, order }));
    expect(result.results.map((item) => item.id)).toEqual(expected.map(uuid));
  });

  it.each([
    { careerId: C },
    { subjectId: S },
    { universityId: U, subjectId: S },
    { professorId: P },
    { universityId: U, careerId: C, professorId: P },
  ])('rechaza la cascada incompleta antes de acceder a dependencias: %j', async (filters) => {
    await expect(service.search(query(filters))).rejects.toBeInstanceOf(BadRequestException);
    expect(catalog.getAcademicContext).not.toHaveBeenCalled();
    expect(material.findCandidates).not.toHaveBeenCalled();
  });

  it.each([
    { universityId: U },
    { universityId: U, careerId: C },
    { universityId: U, careerId: C, subjectId: S },
    academic,
    { year: 2026 },
    { type: 'DOCUMENT' },
  ])('filtra sin q con una combinación válida: %j', async (filters) => {
    rows.push(
      candidate(2, {
        universityId: U2,
        careerId: C2,
        subjectId: S2,
        professorId: P2,
        academicYear: 2025,
        materialType: 'LINK',
      }),
    );
    contexts.push(context({ subjectId: S2, careerId: C2, universityId: U2 }));
    const result = await service.search(query(filters));
    expect(result.total).toBe(1);
    expect(result.results[0].id).toBe(uuid(1001));
  });

  it('combina los seis filtros con texto y encuentra coincidencia solo en descripción', async () => {
    rows = [
      candidate(1, { title: 'Guía', description: 'ÁLGEBRA' }),
      candidate(2, { academicYear: 2025 }),
      candidate(3, { materialType: 'LINK' }),
      candidate(4, { professorId: P2 }),
    ];
    const result = await service.search(
      query({ ...academic, year: 2026, type: 'DOCUMENT', q: '  algebra  ' }),
    );
    expect(result.query).toBe('algebra');
    expect(result.total).toBe(1);
    expect(result.results[0].id).toBe(uuid(1001));
  });

  it.each([
    { universityId: U2, careerId: C },
    { universityId: U, careerId: C2, subjectId: S },
    { ...academic, professorId: uuid(90) },
    { universityId: uuid(99) },
  ])('devuelve 200 lógico vacío para combinación completa incompatible: %j', async (filters) => {
    const result = await service.search(query(filters));
    expect(result).toMatchObject({ total: 0, results: [], context: [] });
  });

  it('no confunde profesor que dicta la asignatura con el asociado al material', async () => {
    rows = [candidate(1, { professorId: P2 }), candidate(2, { professorId: null })];
    expect((await service.search(query(academic))).total).toBe(0);
  });

  it('exige vínculo activo con Catalog además de coincidencia de professorId', async () => {
    contexts = [context({ professors: [] })];
    expect((await service.search(query(academic))).total).toBe(0);
  });

  it('completa referencias nulas con Catalog y devuelve IDs coherentes', async () => {
    rows = [candidate(1, { careerId: null, universityId: null })];
    const result = await service.search(query(academic));
    expect(result.total).toBe(1);
    expect(result.results[0]).toMatchObject({ careerId: C, universityId: U });
  });

  it.each([{ careerId: C2 }, { universityId: U2 }])(
    'excluye referencias contradictorias: %j',
    async (overrides) => {
      rows = [candidate(1, overrides)];
      expect((await service.search(query({ universityId: U }))).total).toBe(0);
    },
  );

  it('sin contexto excluye solo consultas con filtros académicos', async () => {
    contexts = [];
    expect((await service.search(query({ universityId: U }))).total).toBe(0);
    expect((await service.search(query({ year: 2026 }))).total).toBe(1);
    expect((await service.search(query({ q: 'algebra' }))).total).toBe(1);
  });

  it('admite categorías publicadas que no pertenecen al enum de creación', async () => {
    rows = [candidate(1, { materialType: 'APUNTE' })];
    expect((await service.search(query({ type: 'APUNTE' }))).total).toBe(1);
    expect((await service.search(query({ type: 'apunte' }))).total).toBe(0);
    expect((await service.search(query({ type: 'INEXISTENTE' }))).total).toBe(0);
  });

  it('mantiene filtros si q contiene solo espacios', async () => {
    rows.push(candidate(2, { academicYear: 2025 }));
    const result = await service.search(query({ q: '  ', year: 2026 }));
    expect(result.query).toBeNull();
    expect(result.total).toBe(1);
  });

  it('filtra y ordena antes de paginar, incluyendo coincidencias de páginas posteriores', async () => {
    rows = Array.from({ length: 105 }, (_, i) =>
      candidate(i, { academicYear: i % 20 === 0 ? 2026 : 2025 }),
    );
    const result = await service.search(query({ year: 2026, page: 2, pageSize: 2 }));
    expect(result.total).toBe(6);
    expect(result.results.map((item) => item.id)).toEqual([uuid(1060), uuid(1040)]);
    expect(material.findCandidates.mock.calls.map(([arg]: [MaterialPageQuery]) => arg)).toEqual([
      { page: 1, pageSize: 100 },
      { page: 2, pageSize: 100 },
    ]);
  });

  it('ordena globalmente por título incluso sin texto ni filtros', async () => {
    rows = Array.from({ length: 101 }, (_, i) =>
      candidate(i, { title: i === 100 ? 'Alfa' : 'Zeta' }),
    );
    const result = await service.search(
      query({ sortBy: SearchSortBy.TITLE, order: SearchOrder.ASC, pageSize: 1 }),
    );
    expect(result.total).toBe(101);
    expect(result.results[0].id).toBe(uuid(1100));
  });

  it.each([
    [SearchSortBy.CREATED_AT, SearchOrder.ASC, [1002, 1001, 1003]],
    [SearchSortBy.CREATED_AT, SearchOrder.DESC, [1001, 1002, 1003]],
    [SearchSortBy.YEAR, SearchOrder.ASC, [1002, 1001, 1003]],
    [SearchSortBy.YEAR, SearchOrder.DESC, [1001, 1002, 1003]],
  ])('ordena %s %s con nulos al final', async (sortBy, order, expected) => {
    rows = [
      candidate(1, { createdAt: '2026-01-01T00:00:00Z', academicYear: 2026 }),
      candidate(2, { createdAt: '2025-01-01T00:00:00Z', academicYear: 2025 }),
      candidate(3, { createdAt: null, academicYear: null }),
    ];
    const result = await service.search(query({ q: 'guia', sortBy, order }));
    expect(result.results.map((item) => item.id)).toEqual(expected.map(uuid));
  });

  it.each([SearchOrder.ASC, SearchOrder.DESC])(
    'desempata títulos normalizados por id DESC con order=%s',
    async (order) => {
      rows = [candidate(1, { title: 'Álgebra' }), candidate(2, { title: 'algebra' })];
      const result = await service.search(query({ sortBy: SearchSortBy.TITLE, order }));
      expect(result.results.map((item) => item.id)).toEqual([uuid(1002), uuid(1001)]);
    },
  );

  it('produce el mismo orden aunque cambie el orden de recepción de empates', async () => {
    rows = [candidate(1), candidate(3), candidate(2)];
    const first = await service.search(query({ year: 2026 }));
    rows.reverse();
    const second = await service.search(query({ year: 2026 }));
    expect(second).toEqual(first);
    expect(first.results.map((item) => item.id)).toEqual([uuid(1003), uuid(1002), uuid(1001)]);
  });

  it('context incluye solamente las asignaturas de la página final', async () => {
    rows = [candidate(1), candidate(2, { subjectId: S2 })];
    contexts.push(context({ subjectId: S2, subjectName: 'Otra asignatura' }));
    const result = await service.search(query({ year: 2026, pageSize: 1 }));
    expect(result.context.map((item) => item.subjectId)).toEqual([S2]);
  });

  it('una página final fuera de rango conserva total y deja contexto vacío', async () => {
    const result = await service.search(query({ year: 2026, page: 9 }));
    expect(result).toMatchObject({ total: 1, results: [], context: [] });
  });

  it('acepta el límite inclusivo de 10.000 candidatos con filtros', async () => {
    rows = Array.from({ length: 10000 }, (_, i) => candidate(i));
    const result = await service.search(query({ year: 2026, page: 500, pageSize: 20 }));
    expect(result.total).toBe(10000);
    expect(result.results).toHaveLength(20);
    expect(material.findCandidates).toHaveBeenCalledTimes(100);
  });

  it.each([{ year: 2026 }, { universityId: U }, { sortBy: SearchSortBy.TITLE }])(
    'aplica límite sin q: %j',
    async (filters) => {
      material.findCandidates.mockResolvedValue({
        items: Array.from({ length: 100 }, (_, i) => candidate(i)),
        page: 1,
        pageSize: 100,
        total: 10001,
      });
      await expect(service.search(query(filters))).rejects.toBeInstanceOf(
        ServiceUnavailableException,
      );
    },
  );

  it('el listado por defecto conserva la paginación de Material incluso sobre el límite', async () => {
    material.findCandidates.mockResolvedValue({
      items: [],
      page: 1000,
      pageSize: 20,
      total: 10001,
    });
    const result = await service.search(query({ page: 1000 }));
    expect(result.total).toBe(10001);
    expect(material.findCandidates).toHaveBeenCalledWith({ page: 1000, pageSize: 20 });
    expect(material.findCandidates).toHaveBeenCalledTimes(1);
  });

  it('rechaza cambio de total entre páginas', async () => {
    material.findCandidates.mockResolvedValueOnce({
      items: Array.from({ length: 100 }, (_, i) => candidate(i)),
      page: 1,
      pageSize: 100,
      total: 101,
    });
    material.findCandidates.mockResolvedValueOnce({
      items: [],
      page: 2,
      pageSize: 100,
      total: 100,
    });
    await expect(service.search(query({ year: 2026 }))).rejects.toBeInstanceOf(BadGatewayException);
  });
});
