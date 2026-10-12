import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { setupApp } from '../src/setup-app';
import { ObjectStorage } from '../src/application/ports/object-storage.port';
import { MaterialAuthorProvider } from '../src/infrastructure/auth/material-author.provider';

describe('Materials API (E2E)', () => {
  let app: INestApplication;
  const prisma = {
    material: { 
      findMany: jest.fn(), 
      count: jest.fn(),
      create: jest.fn()
    },
    materialType: {
      findFirst: jest.fn()
    },
    $transaction: jest.fn((queries: Promise<unknown>[]) => Promise.all(queries)),
  };

  const storage = { save: jest.fn(), remove: jest.fn() };
  const authorProvider = { resolve: () => ({ id: '18b428c0-6879-4d34-9de8-df9a17438b28', universityId: null }) };

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
    createdAt: '2026-10-01T12:00:00.000Z',
    updatedAt: '2026-10-01T12:00:00.000Z',
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(PrismaService)
      .useValue(prisma)
      .overrideProvider(ObjectStorage)
      .useValue(storage)
      .overrideProvider(MaterialAuthorProvider)
      .useValue(authorProvider)
      .compile();

    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.material.findMany.mockResolvedValue([]);
    prisma.material.count.mockResolvedValue(0);
    prisma.materialType.findFirst.mockResolvedValue({ id: '73dfc2a6-7424-49a1-9449-c66b38cbe771' });
    prisma.material.create.mockImplementation(({ data }) =>
      Promise.resolve({ ...data, id: 'test-material-id', createdAt: new Date() }),
    );
    storage.save.mockResolvedValue('https://storage.url/file.doc');
  });

  afterAll(async () => {
    await app.close();
  });

  describe('GET /api/v1/materials', () => {
    it('devuelve página vacía y valores predeterminados', async () => {
      const { body } = await request(app.getHttpServer()).get('/api/v1/materials').expect(200);
      expect(body).toEqual({ items: [], page: 1, pageSize: 20, total: 0 });
      expect(prisma.material.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ skip: 0, take: 20 }),
      );
    });

    it('pagina publicados con orden estable y serializa metadatos', async () => {
      prisma.material.findMany.mockResolvedValue([{
        ...material,
        createdAt: new Date('2026-10-01T12:00:00Z'),
        updatedAt: new Date('2026-10-01T12:00:00Z'),
      }]);
      prisma.material.count.mockResolvedValue(3);
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/materials?page=2&pageSize=2')
        .expect(200);
      expect(body).toEqual({
        items: [
          {
            ...material,
            materialType: 'CLASS_NOTES',
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

  describe('POST /api/v1/materials - Validaciones de Archivos y Multipart', () => {
    const validMetadata = {
      title: 'Documento de Prueba E2E',
      year: '2026',
      type: 'DOCUMENT',
      subjectId: 'SUBJ-101',
    };

    const MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024;

    it('debería rechazar con 413 un archivo que supere por 1 byte el límite', async () => {
      const oversizedBuffer = Buffer.alloc(MAX_FILE_SIZE_BYTES + 1);

      const { body } = await request(app.getHttpServer())
        .post('/api/v1/materials')
        .field('title', validMetadata.title)
        .field('year', validMetadata.year)
        .field('type', validMetadata.type)
        .field('subjectId', validMetadata.subjectId)
        .attach('file', oversizedBuffer, { filename: 'file-oversized.pdf', contentType: 'application/pdf' })
        .expect(413);

      expect(body.statusCode).toBe(413);
      expect(prisma.material.create).not.toHaveBeenCalled();
      expect(storage.save).not.toHaveBeenCalled();
    });

    it('debería aceptar archivos DOC y PPT con su contenido correspondiente', async () => {
      const docBuffer = Buffer.alloc(1024);
      const pptBuffer = Buffer.alloc(1024);

      await request(app.getHttpServer())
        .post('/api/v1/materials')
        .field('title', 'Apunte Word')
        .field('year', '2026')
        .field('type', 'DOCUMENT')
        .field('subjectId', 'SUBJ-101')
        .attach('file', docBuffer, { filename: 'documento.doc', contentType: 'application/msword' })
        .expect(201);

      await request(app.getHttpServer())
        .post('/api/v1/materials')
        .field('title', 'Presentación PPT')
        .field('year', '2026')
        .field('type', 'PRESENTATION')
        .field('subjectId', 'SUBJ-101')
        .attach('file', pptBuffer, { filename: 'presentacion.ppt', contentType: 'application/vnd.ms-powerpoint' })
        .expect(201);

      expect(storage.save).toHaveBeenCalledTimes(2);
    });

    it('debería rechazar un archivo vacío (0 bytes) con 400 antes de llegar al MIME', async () => {
      const emptyBuffer = Buffer.alloc(0);

      const { body } = await request(app.getHttpServer())
        .post('/api/v1/materials')
        .field('title', validMetadata.title)
        .field('year', validMetadata.year)
        .field('type', validMetadata.type)
        .field('subjectId', validMetadata.subjectId)
        .attach('file', emptyBuffer, { filename: 'empty.pdf', contentType: 'application/pdf' })
        .expect(400);

      expect(body.statusCode).toBe(400);
      expect(prisma.material.create).not.toHaveBeenCalled();
      expect(storage.save).not.toHaveBeenCalled();
    });

    it('no debe invocar el almacenamiento si el tipo MIME no es soportado', async () => {
      const invalidBuffer = Buffer.alloc(100);

      await request(app.getHttpServer())
        .post('/api/v1/materials')
        .field('title', validMetadata.title)
        .field('year', validMetadata.year)
        .field('type', validMetadata.type)
        .field('subjectId', validMetadata.subjectId)
        .attach('file', invalidBuffer, { filename: 'image.png', contentType: 'image/png' })
        .expect(415);

      expect(prisma.material.create).not.toHaveBeenCalled();
      expect(storage.save).not.toHaveBeenCalled();
    });
  });
});