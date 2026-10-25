import { DependencyError } from '../../application/errors/dependency.error';
import { CatalogHttpAdapter } from './catalog-http.adapter';

const fetchMock = jest.fn();

const validSubject = (overrides: Record<string, unknown> = {}) => ({
  id: 'subject-1',
  name: 'Estructuras de Datos',
  code: 'INF-201',
  semester: 3,
  careerId: 'career-1',
  career: {
    id: 'career-1',
    name: 'Ingeniería Civil Informática',
    universityId: 'university-1',
    university: {
      id: 'university-1',
      name: 'Universidad Católica de Temuco',
    },
  },
  professors: [{ id: 'professor-1', name: 'Ada Lovelace' }],
  ...overrides,
});

const respondWith = (body: unknown) =>
  fetchMock.mockResolvedValue({
    ok: true,
    status: 200,
    json: async () => body,
  });

describe('CatalogHttpAdapter', () => {
  beforeEach(() => {
    process.env.CATALOG_SERVICE_URL = 'http://catalog.test:3002';
    global.fetch = fetchMock as unknown as typeof fetch;
  });

  afterEach(() => {
    delete process.env.CATALOG_SERVICE_URL;
    fetchMock.mockReset();
  });

  it('consulta el filtro de Catalog y normaliza el contexto académico', async () => {
    respondWith([validSubject()]);

    const context = await new CatalogHttpAdapter().getAcademicContext();

    expect(fetchMock.mock.calls[0][0]).toBe(
      'http://catalog.test:3002/api/v1/catalog/filter',
    );
    expect(fetchMock.mock.calls[0][1]).toMatchObject({
      headers: { accept: 'application/json' },
    });
    expect(context).toEqual([
      {
        subjectId: 'subject-1',
        subjectName: 'Estructuras de Datos',
        subjectCode: 'INF-201',
        semester: 3,
        careerId: 'career-1',
        careerName: 'Ingeniería Civil Informática',
        universityId: 'university-1',
        universityName: 'Universidad Católica de Temuco',
        professors: [{ id: 'professor-1', name: 'Ada Lovelace' }],
      },
    ]);
  });

  it('lanza DependencyError cuando Catalog responde con error HTTP', async () => {
    fetchMock.mockResolvedValue({
      ok: false,
      status: 500,
      json: async () => ({}),
    });

    await expect(
      new CatalogHttpAdapter().getAcademicContext(),
    ).rejects.toMatchObject({
      service: 'Catalog Service',
      failure: 'upstream-error',
      status: 500,
    });
  });

  it('lanza DependencyError cuando Catalog no está disponible', async () => {
    fetchMock.mockRejectedValue(new TypeError('fetch failed'));

    await expect(
      new CatalogHttpAdapter().getAcademicContext(),
    ).rejects.toMatchObject({
      service: 'Catalog Service',
      failure: 'unavailable',
    });
  });

  it('lanza DependencyError invalid-response cuando el formato no es una lista', async () => {
    respondWith({ subjects: [] });

    await expect(
      new CatalogHttpAdapter().getAcademicContext(),
    ).rejects.toMatchObject({
      failure: 'invalid-response',
    });
  });

  it('lanza DependencyError invalid-response cuando professors no es una lista', async () => {
    respondWith([validSubject({ professors: {} })]);

    await expect(
      new CatalogHttpAdapter().getAcademicContext(),
    ).rejects.toBeInstanceOf(DependencyError);
  });

  it('lanza DependencyError invalid-response cuando un profesor tiene tipos inválidos', async () => {
    respondWith([
      validSubject({ professors: [{ id: 1, name: 'Ada Lovelace' }] }),
    ]);

    await expect(
      new CatalogHttpAdapter().getAcademicContext(),
    ).rejects.toMatchObject({
      failure: 'invalid-response',
    });
  });

  it('lanza DependencyError invalid-response cuando falta la universidad anidada', async () => {
    respondWith([
      validSubject({
        career: {
          id: 'career-1',
          name: 'Ingeniería Civil Informática',
          university: {},
        },
      }),
    ]);

    await expect(
      new CatalogHttpAdapter().getAcademicContext(),
    ).rejects.toMatchObject({
      failure: 'invalid-response',
    });
  });

  it('lanza DependencyError invalid-response cuando semester no es entero', async () => {
    respondWith([validSubject({ semester: '3' })]);

    await expect(
      new CatalogHttpAdapter().getAcademicContext(),
    ).rejects.toMatchObject({
      failure: 'invalid-response',
    });
  });
});
