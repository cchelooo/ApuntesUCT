import {
  BadRequestException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Readable } from 'node:stream';
import { MaterialsService } from './materials.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import {
  ObjectNotFoundError,
  ObjectStorage,
  ObjectStorageError,
} from '../ports/object-storage.port';

describe('MaterialsService', () => {
  const prisma = {
    material: { findMany: jest.fn(), count: jest.fn(), findFirst: jest.fn() },
    materialVersion: { findFirst: jest.fn() },
    $transaction: jest.fn(),
  };
  const storage: jest.Mocked<ObjectStorage> = {
    get: jest.fn(),
    save: jest.fn(),
    remove: jest.fn(),
  };
  const date = new Date('2026-10-01T12:00:00Z');
  const version = {
    id: 'version-2',
    materialId: 'material',
    versionNumber: 2,
    storageKey: 'private/key',
    checksum: 'private-checksum',
    originalFilename: 'apuntes.pdf',
    mimeType: 'application/pdf',
    fileSize: 3n,
    createdAt: date,
  };
  const material = {
    id: 'material',
    title: 'Apuntes',
    description: null,
    uploaderId: 'author',
    academicOfferingId: null,
    universityId: null,
    careerId: null,
    subjectId: 'subject',
    professorId: null,
    materialTypeId: 'type',
    materialType: { name: 'DOCUMENT' },
    academicYear: 2026,
    status: 'PUBLISHED',
    verified: false,
    createdAt: date,
    updatedAt: date,
  };
  let service: MaterialsService;

  beforeEach(() => {
    jest.resetAllMocks();
    service = new MaterialsService(prisma as unknown as PrismaService, storage);
    prisma.$transaction.mockImplementation((queries: Promise<unknown>[]) => Promise.all(queries));
    prisma.material.findMany.mockResolvedValue([material]);
    prisma.material.count.mockResolvedValue(3);
    prisma.material.findFirst.mockResolvedValue({
      ...material,
      externalLink: null,
      versions: [version],
    });
    prisma.materialVersion.findFirst.mockResolvedValue(version);
  });

  it('pagina solo publicados con orden estable y total consistente', async () => {
    await expect(service.list({ page: 2, pageSize: 2 })).resolves.toEqual({
      items: [
        {
          ...material,
          materialType: 'DOCUMENT',
          createdAt: date.toISOString(),
          updatedAt: date.toISOString(),
        },
      ],
      page: 2,
      pageSize: 2,
      total: 3,
    });
    expect(prisma.material.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { status: 'PUBLISHED' },
        skip: 2,
        take: 2,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      }),
    );
    expect(prisma.material.count).toHaveBeenCalledWith({ where: { status: 'PUBLISHED' } });
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Array), {
      isolationLevel: 'RepeatableRead',
    });
    expect(storage.get).not.toHaveBeenCalled();
  });

  it('conserva el total al pedir una página sin resultados', async () => {
    prisma.material.findMany.mockResolvedValue([]);
    await expect(service.list({ page: 9, pageSize: 2 })).resolves.toEqual({
      items: [],
      page: 9,
      pageSize: 2,
      total: 3,
    });
  });

  it('rechaza desplazamientos que exceden el entero de PostgreSQL antes de consultar', async () => {
    await expect(service.list({ page: 2147483647, pageSize: 100 })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.material.findMany).not.toHaveBeenCalled();
    expect(prisma.material.count).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('devuelve el historial completo y la versión actual sin claves internas ni pérdida de precisión', async () => {
    prisma.material.findFirst.mockResolvedValue({
      ...material,
      externalLink: null,
      versions: [
        { ...version, fileSize: 9007199254740993n },
        { ...version, id: 'version-1', versionNumber: 1 },
      ],
    });
    const result = await service.detail('material');
    expect(result.versions.map((item) => item.versionNumber)).toEqual([2, 1]);
    expect(result.currentVersion).toEqual(result.versions[0]);
    expect(result.currentVersion?.fileSize).toBe('9007199254740993');
    expect(result.versions[1].fileSize).toBe('3');
    expect(result.createdAt).toBe(date.toISOString());
    expect(JSON.stringify(result)).not.toMatch(/storageKey|checksum|private/);
    expect(prisma.material.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'material', status: 'PUBLISHED' },
        select: expect.objectContaining({
          versions: {
            orderBy: { versionNumber: 'desc' },
            select: expect.any(Object),
          },
        }),
      }),
    );
    expect(storage.get).not.toHaveBeenCalled();
  });

  it('permite un LINK sin versiones de archivo', async () => {
    prisma.material.findFirst.mockResolvedValue({
      ...material,
      materialType: { name: 'LINK' },
      externalLink: 'https://example.com',
      versions: [],
    });
    await expect(service.detail('material')).resolves.toMatchObject({
      currentVersion: null,
      versions: [],
      externalLink: 'https://example.com',
    });
  });

  it('rechaza documentos sin una versión disponible', async () => {
    prisma.material.findFirst.mockResolvedValue({ ...material, versions: [] });
    await expect(service.detail('material')).rejects.toBeInstanceOf(NotFoundException);
  });

  it.each(['detail', 'download'] as const)(
    '%s rechaza material inexistente o no publicado sin acceder al almacenamiento',
    async (operation) => {
      prisma.material.findFirst.mockResolvedValue(null);
      await expect(service[operation]('missing')).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma.materialVersion.findFirst).not.toHaveBeenCalled();
      expect(storage.get).not.toHaveBeenCalled();
    },
  );

  it.each([undefined, 'version-2'])(
    'descarga la versión solicitada (%s) con sus bytes y metadatos',
    async (versionId) => {
      const stream = Readable.from([Buffer.from('pdf')]);
      storage.get.mockResolvedValue(stream);
      await expect(service.download('material', versionId)).resolves.toEqual({
        stream,
        mimeType: 'application/pdf',
        filename: 'apuntes.pdf',
        size: 3,
      });
      expect(prisma.material.findFirst).toHaveBeenCalledWith({
        where: { id: 'material', status: 'PUBLISHED' },
        select: { id: true },
      });
      expect(prisma.materialVersion.findFirst).toHaveBeenCalledWith(
        versionId
          ? { where: { id: versionId, materialId: 'material' } }
          : { where: { materialId: 'material' }, orderBy: { versionNumber: 'desc' } },
      );
      expect(storage.get).toHaveBeenCalledWith('private/key');
    },
  );

  it('rechaza una versión inexistente o de otro material antes de leer MinIO', async () => {
    prisma.materialVersion.findFirst.mockResolvedValue(null);
    await expect(service.download('material', 'foreign-version')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(storage.get).not.toHaveBeenCalled();
  });

  it.each([
    [new ObjectNotFoundError(), NotFoundException],
    [new ObjectStorageError(), ServiceUnavailableException],
  ])('traduce errores del puerto de almacenamiento (%s)', async (error, expected) => {
    storage.get.mockRejectedValue(error);
    await expect(service.download('material')).rejects.toBeInstanceOf(expected);
  });

  it('propaga fallos inesperados del almacenamiento', async () => {
    const error = new Error('unexpected');
    storage.get.mockRejectedValue(error);
    await expect(service.download('material')).rejects.toBe(error);
  });
});
