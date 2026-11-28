import { ConfigService } from '@nestjs/config';
import { sign } from 'jsonwebtoken';
import { Logger } from '@nestjs/common';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Readable } from 'node:stream';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { ObjectStorage, ObjectStorageError } from '../src/application/ports/object-storage.port';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { setupApp } from '../src/setup-app';

describe('Endpoints administrativos de materiales pendientes (#460)', () => {
  let app: INestApplication;
  const secret = 'admin-pending-test-secret';
  const actorId = '18b428c0-6879-4d34-9de8-df9a17438b28';
  const materialId = 'c0bc574d-41a6-4cb6-9b0f-d3c48b216441';
  const versionId = '05f1c65a-1f3a-4d8e-8c2d-2f8b1a987654';
  const storageKey = 'materials/internal-key-admin';
  const content = Buffer.from('%PDF-1.7 apunte pendiente');
  const date = new Date('2026-11-20T12:00:00Z');
  const version = {
    id: versionId,
    materialId,
    versionNumber: 1,
    storageKey,
    originalFilename: 'apunte-pendiente.pdf',
    mimeType: 'application/pdf',
    fileSize: BigInt(content.length),
    checksum: 'private-checksum',
    createdAt: date,
  };
  const material = {
    id: materialId,
    title: 'Apunte pendiente',
    description: 'En revisión',
    uploaderId: '11111111-1111-4111-8111-111111111111',
    academicOfferingId: null,
    universityId: null,
    careerId: null,
    subjectId: '44444444-4444-4444-8444-444444444444',
    professorId: null,
    materialTypeId: '55555555-5555-4555-8555-555555555555',
    materialType: { name: 'DOCUMENT' },
    academicYear: 2026,
    status: 'PENDING_REVIEW',
    verified: false,
    externalLink: null,
    createdAt: date,
    updatedAt: date,
  };
  const prisma = {
    material: {
      findMany: jest.fn(),
      count: jest.fn(),
      findFirst: jest.fn(),
    },
    materialVersion: { findFirst: jest.fn() },
    $transaction: jest.fn(),
  };
  const storage = { get: jest.fn(), save: jest.fn(), remove: jest.fn() };

  const token = (role?: string) =>
    sign({ sub: actorId, role }, secret, { algorithm: 'HS256', expiresIn: '5m' });
  const authorized = (role: string) => ({ Authorization: `Bearer ${token(role)}` });
  const listPath = '/api/v1/materials/admin/pending';
  const detailPath = `${listPath}/${materialId}`;
  const downloadPath = `${detailPath}/download`;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(ConfigService)
      .useValue({ get: (key: string) => (key === 'JWT_ACCESS_SECRET' ? secret : undefined) })
      .overrideProvider(PrismaService)
      .useValue(prisma)
      .overrideProvider(ObjectStorage)
      .useValue(storage)
      .compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });

  beforeEach(() => {
    jest.resetAllMocks();
    prisma.$transaction.mockImplementation((queries: Promise<unknown>[]) => Promise.all(queries));
    prisma.material.findMany.mockResolvedValue([material]);
    prisma.material.count.mockResolvedValue(1);
    prisma.material.findFirst.mockImplementation(({ where }) =>
      Promise.resolve(where.status === 'PENDING_REVIEW' ? { ...material, versions: [version] } : null),
    );
    prisma.materialVersion.findFirst.mockResolvedValue(version);
    storage.get.mockResolvedValue(Readable.from([content]));
  });

  afterAll(async () => {
    await app.close();
  });

  it.each(['MODERATOR', 'ADMIN'])(
    'permite a %s listar pendientes paginados sin claves internas',
    async (role) => {
      const response = await request(app.getHttpServer())
        .get(`${listPath}?page=2&pageSize=1`)
        .set(authorized(role))
        .expect(200);

      expect(response.body).toEqual({
        items: [
          {
            ...material,
            materialType: 'DOCUMENT',
            status: 'PENDING_REVIEW',
            createdAt: date.toISOString(),
            updatedAt: date.toISOString(),
          },
        ],
        page: 2,
        pageSize: 1,
        total: 1,
      });
      expect(JSON.stringify(response.body)).not.toMatch(/storageKey|checksum|private/);
      expect(prisma.material.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { status: 'PENDING_REVIEW' }, skip: 1, take: 1 }),
      );
      expect(prisma.material.count).toHaveBeenCalledWith({ where: { status: 'PENDING_REVIEW' } });
      expect(response.headers['cache-control']).toBe('no-store');
    },
  );

  it.each(['MODERATOR', 'ADMIN'])('permite a %s consultar el detalle pendiente', async (role) => {
    const response = await request(app.getHttpServer())
      .get(detailPath)
      .set(authorized(role))
      .expect(200);

    expect(response.body.status).toBe('PENDING_REVIEW');
    expect(response.body.currentVersion).toEqual({
      id: versionId,
      versionNumber: 1,
      originalFilename: version.originalFilename,
      mimeType: 'application/pdf',
      fileSize: String(content.length),
      createdAt: date.toISOString(),
    });
    expect(JSON.stringify(response.body)).not.toMatch(/storageKey|checksum|private/);
    expect(prisma.material.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: materialId, status: 'PENDING_REVIEW' } }),
    );
  });

  it.each(['MODERATOR', 'ADMIN'])(
    'permite a %s descargar el archivo pendiente como attachment',
    async (role) => {
      const response = await request(app.getHttpServer())
        .get(downloadPath)
        .set(authorized(role))
        .expect(200);

      expect(response.body).toEqual(content);
      expect(response.headers['content-type']).toBe('application/pdf');
      expect(response.headers['content-length']).toBe(String(content.length));
      expect(response.headers['content-disposition']).toMatch(/^attachment;/);
      expect(response.headers['cache-control']).toBe('no-store');
      expect(JSON.stringify(response.headers)).not.toMatch(/minio|storageKey|internal-key/);
      expect(storage.get).toHaveBeenCalledWith(storageKey);
    },
  );

  it.each([listPath, detailPath, downloadPath])(
    'devuelve 401 sin credenciales en %s',
    async (path) => {
      await request(app.getHttpServer()).get(path).expect(401);
      expect(prisma.material.findMany).not.toHaveBeenCalled();
      expect(prisma.material.findFirst).not.toHaveBeenCalled();
      expect(storage.get).not.toHaveBeenCalled();
    },
  );

  it.each([listPath, detailPath, downloadPath])(
    'devuelve 401 con un token inválido en %s',
    async (path) => {
      await request(app.getHttpServer())
        .get(path)
        .set('Authorization', 'Bearer invalid')
        .expect(401);
      expect(prisma.material.findMany).not.toHaveBeenCalled();
      expect(prisma.material.findFirst).not.toHaveBeenCalled();
      expect(storage.get).not.toHaveBeenCalled();
    },
  );

  it.each(['STUDENT', undefined])('devuelve 403 al rol %s', async (role) => {
    await Promise.all(
      [listPath, detailPath, downloadPath].map((path) =>
        request(app.getHttpServer())
          .get(path)
          .set('Authorization', `Bearer ${token(role)}`)
          .expect(403),
      ),
    );
    expect(prisma.material.findMany).not.toHaveBeenCalled();
    expect(prisma.material.findFirst).not.toHaveBeenCalled();
    expect(storage.get).not.toHaveBeenCalled();
  });

  it.each(['PUBLISHED', 'REJECTED', 'WITHDRAWN'])(
    'no sirve %s por las rutas administrativas',
    async (status) => {
      prisma.material.findFirst.mockImplementation(({ where }) =>
        Promise.resolve(where.status === status ? { ...material, status, versions: [version] } : null),
      );
      await request(app.getHttpServer()).get(detailPath).set(authorized('ADMIN')).expect(404);
      await request(app.getHttpServer()).get(downloadPath).set(authorized('ADMIN')).expect(404);
      expect(storage.get).not.toHaveBeenCalled();
    },
  );

  it.each(['PENDING_REVIEW', 'REJECTED', 'WITHDRAWN'])(
    'mantiene %s fuera de las rutas públicas',
    async (status) => {
      prisma.material.findFirst.mockImplementation(({ where }) =>
        Promise.resolve(
          where.status === status ? { ...material, status, versions: [version] } : null,
        ),
      );
      await request(app.getHttpServer()).get(`/api/v1/materials/${materialId}`).expect(404);
      await request(app.getHttpServer())
        .get(`/api/v1/materials/${materialId}/download`)
        .expect(404);
      await request(app.getHttpServer()).get(`/api/v1/materials/${materialId}/preview`).expect(404);
      expect(storage.get).not.toHaveBeenCalled();
    },
  );

  it('el listado público no incluye materiales pendientes', async () => {
    prisma.material.findMany.mockResolvedValue([]);
    prisma.material.count.mockResolvedValue(0);
    const response = await request(app.getHttpServer()).get('/api/v1/materials').expect(200);
    expect(response.body).toEqual({ items: [], page: 1, pageSize: 20, total: 0 });
    expect(prisma.material.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { status: 'PUBLISHED' } }),
    );
  });

  it('rechaza una versión que pertenece a otro material antes de leer MinIO', async () => {
    prisma.materialVersion.findFirst.mockResolvedValue(null);
    await request(app.getHttpServer())
      .get(`${downloadPath}?versionId=99999999-9999-4999-8999-999999999999`)
      .set(authorized('ADMIN'))
      .expect(404);
    expect(storage.get).not.toHaveBeenCalled();
  });

  it('traduce la indisponibilidad del almacenamiento a 503', async () => {
    storage.get.mockRejectedValue(new ObjectStorageError());
    const response = await request(app.getHttpServer())
      .get(downloadPath)
      .set(authorized('ADMIN'))
      .expect(503);
    expect(response.body.statusCode).toBe(503);
  });

  it.each(['page=0', 'pageSize=101', 'unknown=1'])(
    'rechaza paginación inválida: %s',
    async (query) => {
      await request(app.getHttpServer())
        .get(`${listPath}?${query}`)
        .set(authorized('ADMIN'))
        .expect(400);
      expect(prisma.material.findMany).not.toHaveBeenCalled();
    },
  );

  it.each(['no-uuid', 'abc-123'])('rechaza IDs inválidos en detalle: %s', async (id) => {
    await request(app.getHttpServer())
      .get(`${listPath}/${id}`)
      .set(authorized('ADMIN'))
      .expect(400);
    expect(prisma.material.findFirst).not.toHaveBeenCalled();
  });

  it('audita consultas y descargas sin registrar secretos', async () => {
    const audit = jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
    try {
      await request(app.getHttpServer())
        .get(`${listPath}?page=1&pageSize=5`)
        .set(authorized('MODERATOR'))
        .expect(200);
      await request(app.getHttpServer()).get(detailPath).set(authorized('MODERATOR')).expect(200);
      await request(app.getHttpServer())
        .get(downloadPath)
        .set(authorized('MODERATOR'))
        .expect(200);

      const events = audit.mock.calls.map((call) => call[0] as { event?: string });
      expect(events.map((entry) => entry.event)).toEqual(
        expect.arrayContaining([
          'material.pending.list',
          'material.pending.detail',
          'material.pending.download',
        ]),
      );
      expect(JSON.stringify(audit.mock.calls)).not.toMatch(/storageKey|checksum|private-checksum/);
      expect(JSON.stringify(audit.mock.calls)).toContain(actorId);
    } finally {
      audit.mockRestore();
    }
  });

  it('documenta las tres rutas con respuestas 401 y 403 en OpenAPI', async () => {
    const { body } = await request(app.getHttpServer()).get('/api/docs-json').expect(200);
    for (const path of [
      '/api/v1/materials/admin/pending',
      '/api/v1/materials/admin/pending/{id}',
      '/api/v1/materials/admin/pending/{id}/download',
    ]) {
      expect(body.paths[path]?.get).toBeDefined();
      expect(body.paths[path].get.responses['401']).toBeDefined();
      expect(body.paths[path].get.responses['403']).toBeDefined();
    }
  });
});
