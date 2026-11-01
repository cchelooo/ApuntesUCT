import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { MaterialAuthorProvider } from '../src/infrastructure/auth/material-author.provider';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { ObjectStorage } from '../src/application/ports/object-storage.port';
import { createHash } from 'node:crypto';
import { setupApp } from '../src/setup-app';

describe('POST /materials/:id/versions', () => {
  let app: INestApplication;
  const prisma = {
    material: { findUnique: jest.fn(), update: jest.fn() },
    materialVersion: { findFirst: jest.fn(), create: jest.fn() },
    $queryRaw: jest.fn(),
    $transaction: jest.fn(),
  };
  const storage = { save: jest.fn(), get: jest.fn(), remove: jest.fn() };
  const author = { id: '11111111-1111-4111-8111-111111111111', universityId: null };
  const path = '/api/v1/materials/22222222-2222-4222-8222-222222222222/versions';
  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue(prisma)
      .overrideProvider(ObjectStorage)
      .useValue(storage)
      .overrideProvider(MaterialAuthorProvider)
      .useValue({ resolve: () => author })
      .compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });
  beforeEach(() => {
    jest.resetAllMocks();
    prisma.material.findUnique.mockResolvedValue({
      uploaderId: author.id,
      materialType: { name: 'DOCUMENT' },
    });
    prisma.materialVersion.findFirst.mockResolvedValue({ versionNumber: 1 });
    prisma.materialVersion.create.mockImplementation(({ data }) => ({
      ...data,
      id: '33333333-3333-4333-8333-333333333333',
      createdAt: new Date('2026-10-01T12:00:00Z'),
    }));
    prisma.$transaction.mockImplementation((callback) => callback(prisma));
    storage.save.mockResolvedValue({ storageKey: 'materials/version-2' });
  });
  afterAll(async () => {
    await app.close();
  });

  it('acepta un PDF válido y usa el autor del servidor', async () => {
    const pdf = Buffer.from('%PDF-1.7\nTest\n%%EOF');
    const response = await request(app.getHttpServer())
      .post(path)
      .attach('file', pdf, 'apunte.pdf')
      .expect(201);
    expect(response.body).toEqual({
      id: '33333333-3333-4333-8333-333333333333',
      materialId: '22222222-2222-4222-8222-222222222222',
      versionNumber: 2,
      originalFilename: 'apunte.pdf',
      mimeType: 'application/pdf',
      fileSize: String(pdf.length),
      createdBy: author.id,
      createdAt: '2026-10-01T12:00:00.000Z',
    });
    expect(storage.save).toHaveBeenCalledWith(pdf, 'application/pdf');
    expect(prisma.materialVersion.create).toHaveBeenCalledWith({
      data: {
        materialId: response.body.materialId,
        versionNumber: 2,
        storageKey: 'materials/version-2',
        originalFilename: 'apunte.pdf',
        mimeType: 'application/pdf',
        fileSize: BigInt(pdf.length),
        checksum: createHash('sha256').update(pdf).digest('hex'),
        createdBy: author.id,
      },
    });
    expect(prisma.material.update).toHaveBeenCalledWith({
      where: { id: response.body.materialId },
      data: { updatedAt: expect.any(Date) },
    });
    expect(storage.remove).not.toHaveBeenCalled();
  });

  const expectNoWrites = () => {
    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
    expect(prisma.materialVersion.create).not.toHaveBeenCalled();
  };

  it.each([
    [null, 404],
    [{ uploaderId: 'other', materialType: { name: 'DOCUMENT' } }, 403],
    [{ uploaderId: author.id, materialType: { name: 'LINK' } }, 400],
  ])('rechaza material no elegible con %s / HTTP %s', async (material, status) => {
    prisma.material.findUnique.mockResolvedValue(material);
    const { body } = await request(app.getHttpServer())
      .post(path)
      .attach('file', Buffer.from('%PDF-1.7\n%%EOF'), 'apunte.pdf')
      .expect(status as number);
    expect(body.statusCode).toBe(status);
    expectNoWrites();
  });

  it('devuelve 502 si falla MinIO sin persistir la versión', async () => {
    storage.save.mockRejectedValue(new Error('internal MinIO error'));
    const { body } = await request(app.getHttpServer())
      .post(path)
      .attach('file', Buffer.from('%PDF-1.7\n%%EOF'), 'apunte.pdf')
      .expect(502);
    expect(JSON.stringify(body)).not.toContain('internal MinIO error');
    expect(prisma.$transaction).not.toHaveBeenCalled();
    expect(prisma.materialVersion.create).not.toHaveBeenCalled();
  });
  it('exige archivo', async () => {
    await request(app.getHttpServer()).post(path).expect(400);
    expectNoWrites();
  });
  it('rechaza archivos vacíos', async () => {
    await request(app.getHttpServer())
      .post(path)
      .attach('file', Buffer.alloc(0), 'empty.pdf')
      .expect(400);
    expectNoWrites();
  });
  it('rechaza contenido falso aunque se declare PDF', async () => {
    await request(app.getHttpServer())
      .post(path)
      .attach('file', Buffer.from('fake'), { filename: 'fake.pdf', contentType: 'application/pdf' })
      .expect(415);
    expectNoWrites();
  });
  it('rechaza UUID inválido', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/materials/invalid/versions')
      .attach('file', Buffer.from('%PDF-1.7\n%%EOF'), 'file.pdf')
      .expect(400);
    expectNoWrites();
  });
  it('rechaza archivos que superan 15 MiB', async () => {
    await request(app.getHttpServer())
      .post(path)
      .attach('file', Buffer.alloc(15 * 1024 * 1024 + 1), 'large.pdf')
      .expect(413);
    expectNoWrites();
  });
});
