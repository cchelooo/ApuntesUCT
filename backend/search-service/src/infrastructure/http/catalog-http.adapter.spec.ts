import { DependencyError } from '../../application/errors/dependency.error';
import { CatalogHttpAdapter } from './catalog-http.adapter';

const fetchMock = jest.fn();

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
    fetchMock.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => [
        {
          id: 'subject-1',
          name: 'Estructuras de Datos',
          code: 'INF-201',
          semester: 3,
          career: {
            id: 'career-1',
            name: 'Ingeniería Civil Informática',
            university: {
              id: 'university-1',
              name: 'Universidad Católica de Temuco',
            },
          },
          professors: [{ id: 'professor-1', name: 'Ada Lovelace' }],
        },
      ],
    });

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

  it('lanza DependencyError cuando el formato no es una lista de asignaturas', async () => {
    fetchMock.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ subjects: [] }),
    });

    await expect(
      new CatalogHttpAdapter().getAcademicContext(),
    ).rejects.toBeInstanceOf(DependencyError);
  });
});
