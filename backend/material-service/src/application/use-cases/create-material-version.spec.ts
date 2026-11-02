import { Prisma } from '.prisma/material-client';
import {
  BadGatewayException,
  BadRequestException,
  ForbiddenException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { createHash } from 'node:crypto';
import { CreateMaterialVersion } from './create-material-version';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';

describe('CreateMaterialVersion', () => {
  const author = { id: 'author', universityId: null };
  const file = {
    buffer: Buffer.from('%PDF-1.7\nnew content'),
    originalname: 'apunte.pdf',
    mimetype: 'application/pdf',
  };
  const prisma = {
    material: { findUnique: jest.fn(), update: jest.fn() },
    materialVersion: { findFirst: jest.fn(), create: jest.fn() },
    $queryRaw: jest.fn(),
    $transaction: jest.fn(),
  };
  const storage = { save: jest.fn(), remove: jest.fn(), get: jest.fn() };
  let useCase: CreateMaterialVersion;
  beforeEach(() => {
    jest.resetAllMocks();
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    prisma.material.findUnique.mockResolvedValue({
      uploaderId: author.id,
      materialType: { name: 'DOCUMENT' },
    });
    prisma.materialVersion.findFirst.mockResolvedValue({ versionNumber: 3 });
    prisma.materialVersion.create.mockImplementation(({ data }) => ({
      ...data,
      id: 'version-4',
      createdAt: new Date('2026-10-19T12:00:00Z'),
    }));
    prisma.$transaction.mockImplementation((callback) => callback(prisma));
    storage.save.mockResolvedValue({ storageKey: 'materials/new-object' });
    useCase = new CreateMaterialVersion(prisma as unknown as PrismaService, storage);
  });
  afterEach(() => jest.restoreAllMocks());

  it('agrega la siguiente versión con un objeto nuevo y sin modificar las versiones previas', async () => {
    const result = await useCase.execute('material', author, file);
    expect(result).toMatchObject({
      versionNumber: 4,
      materialId: 'material',
      fileSize: String(file.buffer.length),
    });
    expect(result).not.toHaveProperty('storageKey');
    expect(prisma.materialVersion.create).toHaveBeenCalledWith({
      data: {
        materialId: 'material',
        versionNumber: 4,
        storageKey: 'materials/new-object',
        originalFilename: file.originalname,
        mimeType: file.mimetype,
        fileSize: BigInt(file.buffer.length),
        checksum: createHash('sha256').update(file.buffer).digest('hex'),
        createdBy: author.id,
      },
    });
    expect(storage.save).toHaveBeenCalledWith(file.buffer, file.mimetype);
    expect(storage.remove).not.toHaveBeenCalled();
    expect(prisma.$queryRaw.mock.invocationCallOrder[0]).toBeLessThan(
      prisma.materialVersion.findFirst.mock.invocationCallOrder[0],
    );
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function), {
      isolationLevel: 'ReadCommitted',
    });
  });

  it.each([
    [null, NotFoundException],
    [{ uploaderId: 'other', materialType: { name: 'DOCUMENT' } }, ForbiddenException],
    [{ uploaderId: author.id, materialType: { name: 'LINK' } }, BadRequestException],
  ])('rechaza el material no elegible antes de escribir', async (material, error) => {
    prisma.material.findUnique.mockResolvedValue(material);
    await expect(useCase.execute('material', author, file)).rejects.toBeInstanceOf(error);
    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('no escribe en BD cuando falla almacenamiento', async () => {
    storage.save.mockRejectedValue(new Error('offline'));
    await expect(useCase.execute('material', author, file)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('limpia únicamente el objeto nuevo ante rollback confirmado', async () => {
    const error = new Prisma.PrismaClientKnownRequestError('constraint', {
      code: 'P2002',
      clientVersion: '6.12.0',
    });
    prisma.$transaction.mockRejectedValue(error);
    prisma.materialVersion.findFirst.mockResolvedValue(null);
    await expect(useCase.execute('material', author, file)).rejects.toBe(error);
    expect(storage.remove).toHaveBeenCalledWith('materials/new-object');
  });

  it('conserva el objeto si el resultado de commit es incierto', async () => {
    prisma.$transaction.mockRejectedValue(new Error('connection lost'));
    await expect(useCase.execute('material', author, file)).rejects.toThrow('connection lost');
    expect(storage.remove).not.toHaveBeenCalled();
  });

  it('conserva un objeto que ya tiene una referencia persistida', async () => {
    prisma.$transaction.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('constraint', {
        code: 'P2002',
        clientVersion: '6.12.0',
      }),
    );
    prisma.materialVersion.findFirst.mockResolvedValue({ id: 'persisted' });
    await expect(useCase.execute('material', author, file)).rejects.toThrow();
    expect(storage.remove).not.toHaveBeenCalled();
  });
});
