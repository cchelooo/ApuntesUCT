import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
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
      create: jest.fn(),
    },
    materialType: {
      findFirst: jest.fn(),
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
    storage.save.mockResolvedValue({ storageKey: 'materials/test-file' });
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
    const MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024;
    const validMetadata = {
      title: 'Documento de Prueba E2E',
      year: '2026',
      type: 'DOCUMENT',
      subjectId: 'SUBJ-101',
    };

    // Archivos reales incluidos en el paquete. Se usa el validador de producción.
    const exactPdf = readFileSync(join(__dirname, 'fixtures', 'valid-exact-15mb.pdf'));
    const docBuffer = readFileSync(join(__dirname, 'fixtures', 'valid-document.doc'));
    const pptBuffer = readFileSync(join(__dirname, 'fixtures', 'valid-presentation.ppt'));
    const pngBuffer = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgaPgPAAIDAYAkYfWXAAAAAElFTkSuQmCC',
      'base64',
    );

    const upload = (buffer: Buffer, filename: string, contentType: string, type = 'DOCUMENT') =>
      request(app.getHttpServer())
        .post('/api/v1/materials')
        .field('title', validMetadata.title)
        .field('year', validMetadata.year)
        .field('type', type)
        .field('subjectId', validMetadata.subjectId)
        .attach('file', buffer, { filename, contentType });

    const expectNoWrites = () => {
      expect(storage.save).not.toHaveBeenCalled();
      expect(storage.remove).not.toHaveBeenCalled();
      expect(prisma.material.create).not.toHaveBeenCalled();
    };

    const expectVersion = (buffer: Buffer, filename: string, mimeType: string) => {
      expect(storage.save).toHaveBeenCalledTimes(1);
      expect(storage.save).toHaveBeenCalledWith(buffer, mimeType);
      expect(prisma.material.create).toHaveBeenCalledTimes(1);
      expect(prisma.material.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            status: 'PENDING_REVIEW',
            versions: expect.objectContaining({
              create: expect.objectContaining({
                versionNumber: 1,
                storageKey: 'materials/test-file',
                originalFilename: filename,
                mimeType,
                fileSize: BigInt(buffer.length),
                checksum: createHash('sha256').update(buffer).digest('hex'),
                createdBy: authorProvider.resolve().id,
              }),
            }),
          }),
        }),
      );
    };

    it('acepta un PDF válido de exactamente 15 MiB y persiste la clave en la versión', async () => {
      expect(exactPdf.length).toBe(MAX_FILE_SIZE_BYTES);
      const { body } = await upload(exactPdf, 'exact-15mb.pdf', 'application/pdf').expect(201);
      expectVersion(exactPdf, 'exact-15mb.pdf', 'application/pdf');
      expect(body.data.fileSize).toBe(MAX_FILE_SIZE_BYTES);
      expect(body.data.mimeType).toBe('application/pdf');
      expect(body.data.fileUrl).toBeNull();
      expect(body.data.storageKey).toBeUndefined();
    });

    it('acepta un PDF de un byte menos que el límite', async () => {
      // Solo elimina el salto de línea final; %%EOF queda intacto.
      const buffer = exactPdf.subarray(0, exactPdf.length - 1);
      expect(buffer.length).toBe(MAX_FILE_SIZE_BYTES - 1);
      await upload(buffer, 'below-limit.pdf', 'application/pdf').expect(201);
      expectVersion(buffer, 'below-limit.pdf', 'application/pdf');
    });

    it.each([1, 1024 * 1024])('rechaza con 413 un PDF que supera el límite por %i bytes', async (extra) => {
      // Parte del mismo PDF válido: el rechazo debe deberse al tamaño.
      const buffer = Buffer.concat([exactPdf, Buffer.alloc(extra, 0x0a)]);
      expect(buffer.length).toBe(MAX_FILE_SIZE_BYTES + extra);
      const { body } = await upload(buffer, 'oversized.pdf', 'application/pdf').expect(413);
      expect(body.statusCode).toBe(413);
      expectNoWrites();
    });

    it.each([
      {
        filename: 'documento.doc',
        buffer: docBuffer,
        mimeType: 'application/msword',
        type: 'DOCUMENT',
      },
      {
        filename: 'presentacion.ppt',
        buffer: pptBuffer,
        mimeType: 'application/vnd.ms-powerpoint',
        type: 'PRESENTATION',
      },
    ])('acepta $filename auténtico y registra sus metadatos de versión', async ({ filename, buffer, mimeType, type }) => {
      await upload(buffer, filename, mimeType, type).expect(201);
      expectVersion(buffer, filename, mimeType);
    });

    it.each([
      { filename: 'fake.pdf', contentType: 'application/pdf' },
      { filename: 'fake.doc', contentType: 'application/msword' },
      { filename: 'fake.ppt', contentType: 'application/vnd.ms-powerpoint' },
    ])('rechaza texto falso declarado como $filename con 415', async ({ filename, contentType }) => {
      const buffer = Buffer.from('Texto plano falso que no es un documento real');
      const { body } = await upload(buffer, filename, contentType).expect(415);
      expect(body.statusCode).toBe(415);
      expectNoWrites();
    });

    it.each([
      { filename: 'zeros.doc', contentType: 'application/msword' },
      { filename: 'zeros.ppt', contentType: 'application/vnd.ms-powerpoint' },
    ])('rechaza bytes en cero declarados como $filename con 415', async ({ filename, contentType }) => {
      const { body } = await upload(Buffer.alloc(1024), filename, contentType).expect(415);
      expect(body.statusCode).toBe(415);
      expectNoWrites();
    });

    it.each([
      { filename: 'empty.pdf', contentType: 'application/pdf' },
      { filename: 'empty.doc', contentType: 'application/msword' },
      { filename: 'empty.ppt', contentType: 'application/vnd.ms-powerpoint' },
    ])('rechaza $filename de 0 bytes con 400 antes del filtro de contenido', async ({ filename, contentType }) => {
      const { body } = await upload(Buffer.alloc(0), filename, contentType).expect(400);
      expect(body.statusCode).toBe(400);
      expectNoWrites();
    });

    it.each([
      { filename: 'image.png', contentType: 'image/png' },
      { filename: 'image.pdf', contentType: 'application/pdf' },
    ])('rechaza un PNG real enviado como $filename con 415', async ({ filename, contentType }) => {
      const { body } = await upload(pngBuffer, filename, contentType).expect(415);
      expect(body.statusCode).toBe(415);
      expectNoWrites();
    });
  });
});
