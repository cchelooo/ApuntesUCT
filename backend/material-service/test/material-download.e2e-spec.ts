import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Readable } from 'node:stream';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { ObjectNotFoundError, ObjectStorage, ObjectStorageError } from '../src/application/ports/object-storage.port';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { setupApp } from '../src/setup-app';

describe('GET /api/v1/materials/:id/download', () => {
  let app: INestApplication;
  const prisma = {
    material: { findFirst: jest.fn() },
    materialVersion: { findFirst: jest.fn() },
  };
  const storage = { get: jest.fn(), save: jest.fn() };
  const materialId = 'c0bc574d-41a6-4cb6-9b0f-d3c48b216441';
  const versionId = '05f1c65a-1f3a-4d8e-8c2d-2f8b1a987654';
  const content = Buffer.from('%PDF-1.7\napuntes de calculo\n');
  const version = {
    id: versionId,
    materialId,
    versionNumber: 2,
    storageKey: 'materials/internal-key-2',
    originalFilename: 'apuntes-calculo.pdf',
    mimeType: 'application/pdf',
    fileSize: BigInt(content.length),
    checksum: 'checksum-2',
    createdBy: '18b428c0-6879-4d34-9de8-df9a17438b28',
    createdAt: new Date('2026-10-02T12:00:00Z'),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
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
    jest.clearAllMocks();
    prisma.material.findFirst.mockResolvedValue({ id: materialId });
    prisma.materialVersion.findFirst.mockResolvedValue(version);
    storage.get.mockResolvedValue(Readable.from([content]));
  });

  afterAll(async () => {
    await app.close();
  });

  it('streama la última versión con MIME, nombre adjunto y tamaño', async () => {
    const response = await request(app.getHttpServer())
      .get(`/api/v1/materials/${materialId}/download`)
      .expect(200);
    expect(response.headers['content-type']).toBe('application/pdf');
    expect(response.headers['content-disposition']).toBe(
      `attachment; filename="apuntes-calculo.pdf"; filename*=UTF-8''apuntes-calculo.pdf`,
    );
    expect(response.headers['content-length']).toBe(String(content.length));
    expect(response.body).toEqual(content);
    expect(prisma.material.findFirst).toHaveBeenCalledWith({
      where: { id: materialId, status: 'PUBLISHED' },
      select: { id: true },
    });
    expect(prisma.materialVersion.findFirst).toHaveBeenCalledWith({
      where: { materialId },
      orderBy: { versionNumber: 'desc' },
    });
    expect(storage.get).toHaveBeenCalledWith('materials/internal-key-2');
  });

  it('descarga la versión indicada por versionId sin alterar la clave interna', async () => {
    await request(app.getHttpServer())
      .get(`/api/v1/materials/${materialId}/download?versionId=${versionId}`)
      .expect(200);
    expect(prisma.materialVersion.findFirst).toHaveBeenCalledWith({
      where: { id: versionId, materialId },
    });
  });

  it.each([
    [
      'cálculo.pdf',
      `attachment; filename="calculo.pdf"; filename*=UTF-8''c%C3%A1lculo.pdf`,
    ],
    ['niño.pdf', `attachment; filename="nino.pdf"; filename*=UTF-8''ni%C3%B1o.pdf`],
    [
      'guía de cálculo.pdf',
      `attachment; filename="guia de calculo.pdf"; filename*=UTF-8''gu%C3%ADa%20de%20c%C3%A1lculo.pdf`,
    ],
    [
      'apunte "final".pdf',
      `attachment; filename="apunte _final_.pdf"; filename*=UTF-8''apunte%20%22final%22.pdf`,
    ],
  ])(
    'conserva el nombre especial %s en la cabecera de descarga',
    async (name, expected) => {
      prisma.materialVersion.findFirst.mockResolvedValue({
        ...version,
        originalFilename: name,
      });
      const response = await request(app.getHttpServer())
        .get(`/api/v1/materials/${materialId}/download`)
        .expect(200);
      expect(response.headers['content-disposition']).toBe(expected);
    },
  );

  it('no permite inyectar cabeceras con un nombre malicioso', async () => {
    prisma.materialVersion.findFirst.mockResolvedValue({
      ...version,
      originalFilename: 'informe".pdf\r\nX-Injected: yes',
    });
    const response = await request(app.getHttpServer())
      .get(`/api/v1/materials/${materialId}/download`)
      .expect(200);
    const header = response.headers['content-disposition'];
    expect(header).not.toMatch(/[\r\n]/);
    expect(header).not.toContain('%0d');
    expect(header).not.toContain('%0a');
    expect(header.match(/"/g)).toHaveLength(2);
    expect(response.headers['x-injected']).toBeUndefined();
  });

  it('devuelve 404 para un material inexistente o no publicado', async () => {
    prisma.material.findFirst.mockResolvedValue(null);
    prisma.materialVersion.findFirst.mockResolvedValue(null);
    const { body } = await request(app.getHttpServer())
      .get(`/api/v1/materials/${materialId}/download`)
      .expect(404);
    expect(body.statusCode).toBe(404);
    expect(storage.get).not.toHaveBeenCalled();
  });

  it('devuelve 404 para una versión inexistente del material', async () => {
    prisma.materialVersion.findFirst.mockResolvedValue(null);
    await request(app.getHttpServer())
      .get(`/api/v1/materials/${materialId}/download?versionId=${versionId}`)
      .expect(404);
    expect(storage.get).not.toHaveBeenCalled();
  });

  it('devuelve 404 si la versión resuelve a una clave ausente en MinIO', async () => {
    storage.get.mockRejectedValue(new ObjectNotFoundError());
    const { body } = await request(app.getHttpServer())
      .get(`/api/v1/materials/${materialId}/download`)
      .expect(404);
    expect(body.statusCode).toBe(404);
  });

  it('devuelve 503 si el almacenamiento no está disponible', async () => {
    storage.get.mockRejectedValue(new ObjectStorageError());
    const { body } = await request(app.getHttpServer())
      .get(`/api/v1/materials/${materialId}/download`)
      .expect(503);
    expect(body.statusCode).toBe(503);
  });

  it.each(['no-es-uuid', 'abc-123', 'x'])(
    'rechaza IDs inválidos antes de consultar persistencia: %s',
    async (id) => {
      const { body } = await request(app.getHttpServer())
        .get(`/api/v1/materials/${id}/download`)
        .expect(400);
      expect(body.statusCode).toBe(400);
      expect(prisma.material.findFirst).not.toHaveBeenCalled();
    },
  );

  it.each([
    'versionId=no-es-uuid',
    'page=1',
    'unknown=1',
    'versionId=23b4fd39-1111-2222-3333-444455556666&extra=1',
  ])('rechaza una query inválida: %s', async (query) => {
    const { body } = await request(app.getHttpServer())
      .get(`/api/v1/materials/${materialId}/download?${query}`)
      .expect(400);
    expect(body.statusCode).toBe(400);
    expect(prisma.material.findFirst).not.toHaveBeenCalled();
  });

  it('documenta la ruta, sus parámetros y respuestas en OpenAPI', async () => {
    const { body } = await request(app.getHttpServer()).get('/api/docs-json').expect(200);
    const endpoint = body.paths['/api/v1/materials/{id}/download'].get;
    expect(endpoint).toBeDefined();
    expect(endpoint.parameters.map((p: { name: string }) => p.name)).toEqual(['id', 'versionId']);
    expect(endpoint.parameters[0].in).toBe('path');
    expect(endpoint.parameters[1].in).toBe('query');
    expect(endpoint.responses['404']).toBeDefined();
    expect(endpoint.responses['400']).toBeDefined();
  });
});