import { DependencyError } from '../../application/errors/dependency.error';
import { MaterialHttpAdapter } from './material-http.adapter';

const fetchMock = jest.fn();

const validItem = (overrides: Record<string, unknown> = {}) => ({
  id: 'material-1',
  title: 'Apunte de listas enlazadas',
  description: null,
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

const validPage = (overrides: Record<string, unknown> = {}) => ({
  items: [validItem()],
  page: 2,
  pageSize: 5,
  total: 7,
  ...overrides,
});

const respondWith = (body: unknown) =>
  fetchMock.mockResolvedValue({
    ok: true,
    status: 200,
    json: async () => body,
  });

describe('MaterialHttpAdapter', () => {
  beforeEach(() => {
    process.env.MATERIAL_SERVICE_URL = 'http://material.test:3003';
    global.fetch = fetchMock as unknown as typeof fetch;
  });

  afterEach(() => {
    delete process.env.MATERIAL_SERVICE_URL;
    fetchMock.mockReset();
  });

  it('consulta el listado paginado de Material y normaliza los candidatos', async () => {
    respondWith(validPage());

    const result = await new MaterialHttpAdapter().findCandidates({
      page: 2,
      pageSize: 5,
    });

    expect(fetchMock.mock.calls[0][0]).toBe(
      'http://material.test:3003/api/v1/materials?page=2&pageSize=5',
    );
    expect(result).toEqual({
      items: [
        {
          id: 'material-1',
          title: 'Apunte de listas enlazadas',
          description: null,
          materialType: 'APUNTE',
          academicYear: 2026,
          verified: true,
          subjectId: 'subject-1',
          careerId: 'career-1',
          universityId: 'university-1',
          professorId: 'professor-1',
          createdAt: '2026-10-01T00:00:00.000Z',
          updatedAt: '2026-10-02T00:00:00.000Z',
        },
      ],
      page: 2,
      pageSize: 5,
      total: 7,
    });
  });

  it('lanza DependencyError cuando Material responde con error HTTP', async () => {
    fetchMock.mockResolvedValue({
      ok: false,
      status: 503,
      json: async () => ({}),
    });

    await expect(
      new MaterialHttpAdapter().findCandidates({ page: 1, pageSize: 20 }),
    ).rejects.toMatchObject({
      service: 'Material Service',
      failure: 'upstream-error',
      status: 503,
    });
  });

  it('lanza DependencyError cuando Material no está disponible', async () => {
    fetchMock.mockRejectedValue(new TypeError('fetch failed'));

    await expect(
      new MaterialHttpAdapter().findCandidates({ page: 1, pageSize: 20 }),
    ).rejects.toMatchObject({
      service: 'Material Service',
      failure: 'unavailable',
    });
  });

  it('lanza DependencyError invalid-response cuando falta la lista de materiales', async () => {
    respondWith({ page: 1, pageSize: 20, total: 0 });

    await expect(
      new MaterialHttpAdapter().findCandidates({ page: 1, pageSize: 20 }),
    ).rejects.toBeInstanceOf(DependencyError);
  });

  it('lanza DependencyError invalid-response cuando verified no es booleano', async () => {
    respondWith(validPage({ items: [validItem({ verified: 'sí' })] }));

    await expect(
      new MaterialHttpAdapter().findCandidates({ page: 2, pageSize: 5 }),
    ).rejects.toMatchObject({
      failure: 'invalid-response',
    });
  });

  it('lanza DependencyError invalid-response cuando academicYear no es entero', async () => {
    respondWith(validPage({ items: [validItem({ academicYear: '2026' })] }));

    await expect(
      new MaterialHttpAdapter().findCandidates({ page: 2, pageSize: 5 }),
    ).rejects.toMatchObject({
      failure: 'invalid-response',
    });
  });

  it('lanza DependencyError invalid-response cuando un material no es un objeto', async () => {
    respondWith(validPage({ items: [null] }));

    await expect(
      new MaterialHttpAdapter().findCandidates({ page: 2, pageSize: 5 }),
    ).rejects.toMatchObject({
      failure: 'invalid-response',
    });
  });

  it('lanza DependencyError invalid-response cuando una fecha no es válida', async () => {
    respondWith(
      validPage({ items: [validItem({ createdAt: 'no-es-una-fecha' })] }),
    );

    await expect(
      new MaterialHttpAdapter().findCandidates({ page: 2, pageSize: 5 }),
    ).rejects.toMatchObject({
      failure: 'invalid-response',
    });
  });

  it('lanza DependencyError invalid-response cuando la paginación no es numérica', async () => {
    respondWith(validPage({ page: '2' }));

    await expect(
      new MaterialHttpAdapter().findCandidates({ page: 2, pageSize: 5 }),
    ).rejects.toMatchObject({
      failure: 'invalid-response',
    });
  });
});
