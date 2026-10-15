import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { Readable } from 'node:stream';
import { MaterialsController } from '../src/presentation/materials/materials.controller';
import { MaterialsService } from '../src/application/services/materials.service';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { ObjectStorage } from '../src/application/ports/object-storage.port';
import { setupApp } from '../src/setup-app';

const MATERIAL_ID = '11111111-1111-4111-8111-111111111111';
const VERSION_ID = '22222222-2222-4222-8222-222222222222';
const DATE = new Date('2026-10-01T12:00:00.000Z');

const row = () => ({
  id: MATERIAL_ID,
  title: 'Apuntes de cálculo',
  description: null,
  uploaderId: '33333333-3333-4333-8333-333333333333',
  academicOfferingId: null,
  universityId: null,
  careerId: null,
  subjectId: '44444444-4444-4444-8444-444444444444',
  professorId: null,
  materialTypeId: '55555555-5555-4555-8555-555555555555',
  materialType: { name: 'DOCUMENT' },
  academicYear: 2026,
  status: 'PUBLISHED',
  verified: false,
  externalLink: null,
  createdAt: DATE,
  updatedAt: DATE,
  versions: [
    {
      id: VERSION_ID,
      versionNumber: 3,
      originalFilename: 'apuntes.pdf',
      mimeType: 'application/pdf',
      fileSize: 15728640n,
      createdAt: DATE,
      // Campos extra del mock: el mapeo HTTP también debe impedir su exposición.
      storageKey: 'materials/private-key',
      checksum: 'internal-checksum',
    },
  ],
});

describe('GET /materials/:id - detalle', () => {
  let app: INestApplication;
  const prisma = {
    material: { findFirst: jest.fn(), findMany: jest.fn(), count: jest.fn() },
    materialVersion: { findFirst: jest.fn() },
  };
  const storage = { get: jest.fn(), save: jest.fn(), remove: jest.fn() };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [MaterialsController],
      providers: [
        MaterialsService,
        { provide: PrismaService, useValue: prisma },
        { provide: ObjectStorage, useValue: storage },
      ],
    }).compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });

  beforeEach(() => {
    jest.resetAllMocks();
    prisma.material.findFirst.mockResolvedValue(row());
  });

  afterAll(async () => {
    await app.close();
  });

  it('devuelve metadatos y versión actual sin claves internas', async () => {
    const { body } = await request(app.getHttpServer())
      .get(`/api/v1/materials/${MATERIAL_ID}`)
      .expect(200);
    expect(body).toEqual({
      id: MATERIAL_ID,
      title: 'Apuntes de cálculo',
      description: null,
      uploaderId: row().uploaderId,
      academicOfferingId: null,
      universityId: null,
      careerId: null,
      subjectId: row().subjectId,
      professorId: null,
      materialTypeId: row().materialTypeId,
      materialType: 'DOCUMENT',
      academicYear: 2026,
      status: 'PUBLISHED',
      verified: false,
      externalLink: null,
      createdAt: DATE.toISOString(),
      updatedAt: DATE.toISOString(),
      currentVersion: {
        id: VERSION_ID,
        versionNumber: 3,
        originalFilename: 'apuntes.pdf',
        mimeType: 'application/pdf',
        fileSize: '15728640',
        createdAt: DATE.toISOString(),
      },
    });
    expect(JSON.stringify(body)).not.toContain('private-key');
    expect(body.currentVersion.storageKey).toBeUndefined();
    expect(body.currentVersion.checksum).toBeUndefined();
    expect(storage.get).not.toHaveBeenCalled();
    expect(prisma.materialVersion.findFirst).not.toHaveBeenCalled();
    expect(prisma.material.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: MATERIAL_ID, status: 'PUBLISHED' },
        select: expect.objectContaining({
          versions: expect.objectContaining({ orderBy: { versionNumber: 'desc' }, take: 1 }),
        }),
      }),
    );
  });

  it('solicita la mayor versión por número, sin ordenar por fecha', async () => {
    const latest = row().versions[0];
    const older = {
      ...latest,
      id: '66666666-6666-4666-8666-666666666666',
      versionNumber: 1,
      createdAt: new Date('2026-10-12'),
    };
    prisma.material.findFirst.mockImplementation(({ select }) => {
      const versions =
        select.versions.orderBy.versionNumber === 'desc'
          ? [older, latest]
              .sort((a, b) => b.versionNumber - a.versionNumber)
              .slice(0, select.versions.take)
          : [older];
      return Promise.resolve({ ...row(), versions });
    });
    const { body } = await request(app.getHttpServer())
      .get(`/api/v1/materials/${MATERIAL_ID}`)
      .expect(200);
    expect(body.currentVersion.id).toBe(VERSION_ID);
    expect(body.currentVersion.versionNumber).toBe(3);
  });

  it('devuelve 404 para un UUID inexistente', async () => {
    prisma.material.findFirst.mockResolvedValue(null);
    await request(app.getHttpServer()).get(`/api/v1/materials/${MATERIAL_ID}`).expect(404);
    expect(storage.get).not.toHaveBeenCalled();
  });

  it.each(['PENDING_REVIEW', 'REJECTED', 'WITHDRAWN'])(
    'oculta materiales %s con 404',
    async (status) => {
      prisma.material.findFirst.mockImplementation(({ where }) =>
        Promise.resolve(where.status === status ? { ...row(), status } : null),
      );
      await request(app.getHttpServer()).get(`/api/v1/materials/${MATERIAL_ID}`).expect(404);
    },
  );

  it('rechaza un ID mal formado antes de consultar Prisma', async () => {
    await request(app.getHttpServer()).get('/api/v1/materials/no-es-uuid').expect(400);
    expect(prisma.material.findFirst).not.toHaveBeenCalled();
  });

  it('devuelve LINK con currentVersion null', async () => {
    prisma.material.findFirst.mockResolvedValue({
      ...row(),
      materialType: { name: 'LINK' },
      externalLink: 'https://example.com/apunte',
      versions: [],
    });
    const { body } = await request(app.getHttpServer())
      .get(`/api/v1/materials/${MATERIAL_ID}`)
      .expect(200);
    expect(body.materialType).toBe('LINK');
    expect(body.externalLink).toBe('https://example.com/apunte');
    expect(body.currentVersion).toBeNull();
  });

  it('devuelve 404 para un documento que no tiene versión', async () => {
    prisma.material.findFirst.mockResolvedValue({ ...row(), versions: [] });
    await request(app.getHttpServer()).get(`/api/v1/materials/${MATERIAL_ID}`).expect(404);
  });

  it('serializa BigInt sin perder precisión', async () => {
    const material = row();
    material.versions[0].fileSize = 9007199254740993n;
    prisma.material.findFirst.mockResolvedValue(material);
    const { body } = await request(app.getHttpServer())
      .get(`/api/v1/materials/${MATERIAL_ID}`)
      .expect(200);
    expect(body.currentVersion.fileSize).toBe('9007199254740993');
  });

  it('conserva la ruta de descarga y su stream', async () => {
    prisma.material.findFirst.mockResolvedValue({ id: MATERIAL_ID });
    prisma.materialVersion.findFirst.mockResolvedValue({ ...row().versions[0], fileSize: 3n });
    storage.get.mockResolvedValue(Readable.from(Buffer.from('abc')));
    const response = await request(app.getHttpServer())
      .get(`/api/v1/materials/${MATERIAL_ID}/download`)
      .expect(200);
    expect(response.headers['content-type']).toContain('application/pdf');
    expect(response.headers['content-length']).toBe('3');
    expect(storage.get).toHaveBeenCalledWith('materials/private-key');
  });

  it('documenta el detalle y la versión en Swagger', async () => {
    const { body } = await request(app.getHttpServer()).get('/api/docs-json').expect(200);
    const endpoint = body.paths['/api/v1/materials/{id}'].get;
    expect(endpoint.responses['200'].content['application/json'].schema.$ref).toBe(
      '#/components/schemas/MaterialDetailDto',
    );
    expect(endpoint.responses['404']).toBeDefined();
    expect(body.components.schemas.MaterialCurrentVersionDto.properties.fileSize.type).toBe(
      'string',
    );
    expect(body.components.schemas.MaterialDetailDto.properties.currentVersion.nullable).toBe(true);
  });
});
