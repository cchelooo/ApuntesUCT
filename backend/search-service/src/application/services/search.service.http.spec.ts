import {
  BadGatewayException,
  BadRequestException,
} from '@nestjs/common';
import { CatalogHttpAdapter } from '../../infrastructure/http/catalog-http.adapter';
import { MaterialHttpAdapter } from '../../infrastructure/http/material-http.adapter';
import { SearchQueryDto } from '../dtos/search-query.dto';
import { SearchService } from './search.service';

const fetchMock = jest.fn();

const catalogPayload = () => [
  {
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
  },
];

const materialItem = () => ({
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
});

const materialPage = () => ({
  items: [materialItem()],
  page: 1,
  pageSize: 20,
  total: 1,
});

const jsonResponse = (body: unknown) => ({
  ok: true,
  status: 200,
  json: async () => body,
});

const searchQuery = (overrides: Partial<SearchQueryDto> = {}) =>
  Object.assign(new SearchQueryDto(), overrides);

describe('SearchService con adaptadores HTTP', () => {
  let service: SearchService;

  beforeEach(() => {
    process.env.CATALOG_SERVICE_URL = 'http://catalog.test:3002';
    process.env.MATERIAL_SERVICE_URL = 'http://material.test:3003';
    global.fetch = fetchMock as unknown as typeof fetch;
    service = new SearchService(
      new CatalogHttpAdapter(),
      new MaterialHttpAdapter(),
    );
  });

  afterEach(() => {
    delete process.env.CATALOG_SERVICE_URL;
    delete process.env.MATERIAL_SERVICE_URL;
    fetchMock.mockReset();
  });

  it('compone respuestas HTTP válidas de ambos servicios', async () => {
    fetchMock.mockImplementation(async (url: string) =>
      url.includes('/catalog/')
        ? jsonResponse(catalogPayload())
        : jsonResponse(materialPage()),
    );

    const response = await service.search(searchQuery());

    expect(response.results[0]).toMatchObject({
      id: 'material-1',
      subjectName: 'Estructuras de Datos',
      careerName: 'Ingeniería Civil Informática',
      universityName: 'Universidad Católica de Temuco',
    });
  });

  it('devuelve 502 cuando Material entrega un booleano inválido', async () => {
    fetchMock.mockImplementation(async (url: string) =>
      url.includes('/catalog/')
        ? jsonResponse(catalogPayload())
        : jsonResponse({
            ...materialPage(),
            items: [{ ...materialItem(), verified: 'sí' }],
          }),
    );

    await expect(service.search(searchQuery())).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it('devuelve 502 cuando Catalog entrega profesores con formato inválido', async () => {
    fetchMock.mockImplementation(async (url: string) =>
      url.includes('/catalog/')
        ? jsonResponse([{ ...catalogPayload()[0], professors: {} }])
        : jsonResponse(materialPage()),
    );

    await expect(service.search(searchQuery())).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it('devuelve 400 cuando Material rechaza la paginación', async () => {
    fetchMock.mockImplementation(async (url: string) => {
      if (url.includes('/catalog/')) {
        return jsonResponse(catalogPayload());
      }

      return {
        ok: false,
        status: 400,
        json: async () => ({
          message: 'El desplazamiento de página excede el máximo permitido.',
        }),
      };
    });

    await expect(
      service.search(
        searchQuery({ page: 2147483647, pageSize: 100 }),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
