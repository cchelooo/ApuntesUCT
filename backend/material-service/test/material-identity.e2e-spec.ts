import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { sign } from 'jsonwebtoken';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { ObjectStorage } from '../src/application/ports/object-storage.port';
import { CatalogPort } from '../src/application/ports/catalog.port';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { setupApp } from '../src/setup-app';

const SECRET = 'e2e-only-secret-with-enough-entropy';
const AUTHOR_ID = '11111111-1111-4111-8111-111111111111';
const OTHER_ID = '22222222-2222-4222-8222-222222222222';
const MATERIAL_ID = '33333333-3333-4333-8333-333333333333';
const LINK_BODY = {
  title: 'Apunte con identidad real',
  subjectId: '44444444-4444-4444-8444-444444444444',
  year: '2026',
  type: 'LINK',
  externalLink: 'https://example.com/apunte',
};

function token(sub: string, overrides: Record<string, unknown> = {}): string {
  return sign(
    { sub, email: 'estudiante@alu.uct.cl', role: 'STUDENT', ...overrides },
    SECRET,
    { algorithm: 'HS256', expiresIn: '5m' },
  );
}

function noneToken(sub: string): string {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub, exp: Math.floor(Date.now() / 1000) + 60 }),
  ).toString('base64url');
  return `${header}.${payload}.`;
}

describe('Identidad real en subida y versionado de Material (#446)', () => {
  let app: INestApplication;
  const prisma = {
    materialType: { findFirst: jest.fn() },
    material: { create: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
    materialVersion: { findFirst: jest.fn(), create: jest.fn() },
    $queryRaw: jest.fn(),
    $transaction: jest.fn(),
  };
  const storage = { save: jest.fn(), get: jest.fn(), remove: jest.fn() };
  const catalog = { validateReferences: jest.fn() };

  beforeAll(async () => {
    process.env.JWT_ACCESS_SECRET = SECRET;
    process.env.NODE_ENV = 'test';
    delete process.env.MATERIAL_LOCAL_AUTHOR_ENABLED;
    delete process.env.MATERIAL_LOCAL_UPLOADER_ID;

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue(prisma)
      .overrideProvider(ObjectStorage)
      .useValue(storage)
      .overrideProvider(CatalogPort)
      .useValue(catalog)
      .compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });

  beforeEach(() => {
    jest.resetAllMocks();
    catalog.validateReferences.mockResolvedValue(undefined);
    storage.save.mockResolvedValue({ storageKey: 'materials/version' });
    prisma.materialType.findFirst.mockResolvedValue({ id: 'type-id' });
    prisma.material.create.mockImplementation(({ data }) =>
      Promise.resolve({
        ...data,
        id: MATERIAL_ID,
        description: null,
        status: 'PENDING_REVIEW',
        createdAt: new Date('2026-11-15T12:00:00Z'),
      }),
    );
    prisma.material.findUnique.mockResolvedValue({
      uploaderId: AUTHOR_ID,
      materialType: { name: 'DOCUMENT' },
    });
    prisma.materialVersion.findFirst.mockResolvedValue({ versionNumber: 1 });
    prisma.materialVersion.create.mockImplementation(({ data }) => ({
      ...data,
      id: '55555555-5555-4555-8555-555555555555',
      createdAt: new Date('2026-11-15T12:00:00Z'),
    }));
    prisma.$transaction.mockImplementation((callback) => callback(prisma));
  });

  afterAll(async () => {
    await app.close();
    delete process.env.JWT_ACCESS_SECRET;
  });

  const upload = (headers: Record<string, string> = {}) =>
    request(app.getHttpServer())
      .post('/api/v1/materials')
      .set(headers)
      .field(LINK_BODY);

  it('rechaza la subida sin token cuando no hay contexto local', async () => {
    await upload().expect(401);
    expect(prisma.material.create).not.toHaveBeenCalled();
  });

  it.each([
    ['firma inválida', () => sign({ sub: AUTHOR_ID, exp: 9999999999 }, 'otro-secreto')],
    ['alg none', () => noneToken(AUTHOR_ID)],
    ['token mock', () => token(AUTHOR_ID, { mock: true })],
  ])('rechaza la subida con %s', async (_case, build) => {
    await upload({ Authorization: `Bearer ${build()}` }).expect(401);
    expect(prisma.material.create).not.toHaveBeenCalled();
  });

  it('sube usando el sub del token como autor', async () => {
    const response = await upload({ Authorization: `Bearer ${token(AUTHOR_ID)}` }).expect(201);

    expect(response.body.data.id).toBe(MATERIAL_ID);
    expect(prisma.material.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ uploaderId: AUTHOR_ID }),
    });
  });

  it('ignora el uploaderId enviado por el cliente', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/materials')
      .set('Authorization', `Bearer ${token(AUTHOR_ID)}`)
      .field({ ...LINK_BODY, uploaderId: OTHER_ID })
      .expect(400);
    expect(prisma.material.create).not.toHaveBeenCalled();
  });

  it('crea una versión cuando el token corresponde al autor', async () => {
    const response = await request(app.getHttpServer())
      .post(`/api/v1/materials/${MATERIAL_ID}/versions`)
      .set('Authorization', `Bearer ${token(AUTHOR_ID)}`)
      .attach('file', Buffer.from('%PDF-1.7\nContenido\n%%EOF'), 'apunte.pdf')
      .expect(201);

    expect(response.body.createdBy).toBe(AUTHOR_ID);
    expect(prisma.materialVersion.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ createdBy: AUTHOR_ID }),
    });
  });

  it('devuelve 403 cuando otro usuario autenticado intenta versionar', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/materials/${MATERIAL_ID}/versions`)
      .set('Authorization', `Bearer ${token(OTHER_ID)}`)
      .attach('file', Buffer.from('%PDF-1.7\nContenido\n%%EOF'), 'apunte.pdf')
      .expect(403);

    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.materialVersion.create).not.toHaveBeenCalled();
  });

  it('rechaza versionar con firma inválida', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/materials/${MATERIAL_ID}/versions`)
      .set('Authorization', `Bearer ${sign({ sub: AUTHOR_ID }, 'otro-secreto')}`)
      .attach('file', Buffer.from('%PDF-1.7\nContenido\n%%EOF'), 'apunte.pdf')
      .expect(401);

    expect(storage.save).not.toHaveBeenCalled();
  });
});
