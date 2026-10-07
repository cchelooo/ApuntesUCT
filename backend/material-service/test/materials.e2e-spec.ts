import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { setupApp } from '../src/setup-app';

describe('GET /api/v1/materials', () => {
  let app: INestApplication;
  const prisma = {
    material: { findMany: jest.fn(), count: jest.fn() },
    $transaction: jest.fn((queries: Promise<unknown>[]) => Promise.all(queries)),
  };
  const material = {
    id: 'c0bc574d-41a6-4cb6-9b0f-d3c48b216441',
    title: 'Apuntes de cálculo',
    description: null,
    uploaderId: '18b428c0-6879-4d34-9de8-df9a17438b28',
    academicOfferingId: null,
    universityId: null,
    careerId: null,
    subjectId: 'calculo-1',
    professorId: null,
    materialTypeId: '73dfc2a6-7424-49a1-9449-c66b38cbe771',
    materialType: { name: 'CLASS_NOTES' },
    academicYear: 2026,
    status: 'PUBLISHED',
    verified: false,
    createdAt: new Date('2026-10-01T12:00:00Z'),
    updatedAt: new Date('2026-10-01T12:00:00Z'),
  };
  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue(prisma)
      .compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });
  beforeEach(() => {
    jest.clearAllMocks();
    prisma.material.findMany.mockResolvedValue([]);
    prisma.material.count.mockResolvedValue(0);
  });
  afterAll(async () => {
    await app.close();
  });

  it('devuelve página vacía y valores predeterminados', async () => {
    const { body } = await request(app.getHttpServer()).get('/api/v1/materials').expect(200);
    expect(body).toEqual({ items: [], page: 1, pageSize: 20, total: 0 });
    expect(prisma.material.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ skip: 0, take: 20 }),
    );
  });
  it('pagina publicados con orden estable y serializa metadatos', async () => {
    prisma.material.findMany.mockResolvedValue([material]);
    prisma.material.count.mockResolvedValue(3);
    const { body } = await request(app.getHttpServer())
      .get('/api/v1/materials?page=2&pageSize=2')
      .expect(200);
    expect(body).toEqual({
      items: [
        {
          ...material,
          materialType: 'CLASS_NOTES',
          createdAt: '2026-10-01T12:00:00.000Z',
          updatedAt: '2026-10-01T12:00:00.000Z',
        },
      ],
      page: 2,
      pageSize: 2,
      total: 3,
    });
    expect(prisma.material.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        skip: 2,
        take: 2,
        where: { status: 'PUBLISHED' },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      }),
    );
    expect(prisma.material.count).toHaveBeenCalledWith({ where: { status: 'PUBLISHED' } });
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Array), {
      isolationLevel: 'RepeatableRead',
    });
    expect(prisma.material.findMany.mock.calls[0][0].select.versions).toBeUndefined();
  });
  it('conserva total y página fuera de rango', async () => {
    prisma.material.count.mockResolvedValue(3);
    const { body } = await request(app.getHttpServer())
      .get('/api/v1/materials?page=9&pageSize=2')
      .expect(200);
    expect(body).toEqual({ items: [], page: 9, pageSize: 2, total: 3 });
  });
  it('acepta el tamaño máximo', async () => {
    await request(app.getHttpServer()).get('/api/v1/materials?pageSize=100').expect(200);
    expect(prisma.material.findMany).toHaveBeenCalledWith(expect.objectContaining({ take: 100 }));
  });
  it.each([
    'page=0',
    'page=-1',
    'page=1.5',
    'page=abc',
    'page=',
    'page=1e2',
    'page=0x10',
    'page=1&page=2',
    'pageSize=0',
    'pageSize=-2',
    'pageSize=101',
    'pageSize=1.2',
    'pageSize=',
    'pageSize=no',
    'pageSize=2&pageSize=3',
    'page=9007199254740992',
    'page=2147483647&pageSize=100',
    'q=calculo',
    'status=PENDING_REVIEW',
  ])('rechaza %s antes de consultar persistencia', async (query) => {
    const { body } = await request(app.getHttpServer())
      .get(`/api/v1/materials?${query}`)
      .expect(400);
    expect(body.statusCode).toBe(400);
    expect(prisma.material.findMany).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
  it('documenta parámetros y respuesta en OpenAPI', async () => {
    const { body } = await request(app.getHttpServer()).get('/api/docs-json').expect(200);
    const endpoint = body.paths['/api/v1/materials'].get;
    expect(endpoint.parameters.map((p: { name: string }) => p.name)).toEqual(['page', 'pageSize']);
    expect(endpoint.responses['200'].content['application/json'].schema.$ref).toBe(
      '#/components/schemas/MaterialPageDto',
    );
    expect(body.components.schemas.MaterialPageDto.required).toEqual([
      'items',
      'page',
      'pageSize',
      'total',
    ]);
    expect(body.components.schemas.MaterialSummaryDto.properties.description.nullable).toBe(true);
  });
});
