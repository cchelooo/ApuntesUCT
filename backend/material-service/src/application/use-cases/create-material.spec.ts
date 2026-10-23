import { Prisma } from '.prisma/material-client';
import { BadGatewayException, BadRequestException, Logger } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { CreateMaterial } from './create-material';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { ObjectStorage } from '../ports/object-storage.port';
import {
  CatalogPort,
  CatalogUnavailableError,
  InvalidAcademicReferenceError,
} from '../ports/catalog.port';

describe('CreateMaterial', () => {
  const prisma = {
    materialType: { findFirst: jest.fn() },
    material: { create: jest.fn() },
    materialVersion: { findFirst: jest.fn() },
  };
  const catalog: jest.Mocked<CatalogPort> = {
    validateReferences: jest.fn(),
  };
  const storage: jest.Mocked<ObjectStorage> = {
    save: jest.fn(),
    remove: jest.fn(),
    get: jest.fn(),
  };
  const author = { id: '11111111-1111-4111-8111-111111111111', universityId: null };
  const input = { title: 'Apunte', type: 'DOCUMENT', year: '2026', subjectId: 'subject-1' };
  const file = {
    buffer: Buffer.from('%PDF-1.7\n'),
    originalname: '../../apunte.pdf',
    mimetype: 'application/pdf',
  };
  let useCase: CreateMaterial;

  beforeEach(() => {
    jest.resetAllMocks();
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    prisma.materialVersion.findFirst.mockResolvedValue(null);
    catalog.validateReferences.mockResolvedValue(undefined);
    storage.remove.mockResolvedValue(undefined);
    prisma.materialType.findFirst.mockResolvedValue({ id: 'type-id' });
    storage.save.mockResolvedValue({ storageKey: 'materials/internal-key' });
    prisma.material.create.mockImplementation(({ data }) =>
      Promise.resolve({
        ...data,
        id: 'material-id',
        createdAt: new Date('2026-10-11T12:00:00Z'),
      }),
    );
    // Orden del constructor: Prisma, almacenamiento y Catalog.
    useCase = new CreateMaterial(prisma as unknown as PrismaService, storage, catalog);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('guarda antes de crear material y versión atómicamente con checksum y autor', async () => {
    prisma.material.create.mockImplementation(({ data }) => {
      expect(storage.save).toHaveBeenCalledWith(file.buffer, file.mimetype);
      return Promise.resolve({ ...data, id: 'material-id', createdAt: new Date() });
    });
    const result = await useCase.execute(input, author, file);
    expect(catalog.validateReferences).toHaveBeenCalledWith({
      subjectId: input.subjectId,
      careerId: undefined,
      professorId: undefined,
      universityId: author.universityId,
    });
    expect(prisma.material.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        status: 'PENDING_REVIEW',
        academicYear: 2026,
        uploaderId: author.id,
        versions: {
          create: {
            versionNumber: 1,
            storageKey: 'materials/internal-key',
            originalFilename: file.originalname,
            mimeType: file.mimetype,
            fileSize: BigInt(file.buffer.length),
            checksum: createHash('sha256').update(file.buffer).digest('hex'),
            createdBy: author.id,
          },
        },
      }),
    });
    expect(result.isSimulatedResponse).toBe(false);
    expect(result.data.status).toBe('PENDING_REVIEW');
    expect(result.data.fileUrl).toBeNull();
    expect(JSON.stringify(result)).not.toContain('internal-key');
  });

  it('espera la confirmación de Catalog antes de almacenar o persistir', async () => {
    let confirm!: () => void;
    catalog.validateReferences.mockImplementation(
      () => new Promise<void>((resolve) => { confirm = resolve; }),
    );
    const pending = useCase.execute(input, author, file);
    await new Promise<void>((resolve) => setImmediate(resolve));
    expect(catalog.validateReferences).toHaveBeenCalledTimes(1);
    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.material.create).not.toHaveBeenCalled();
    confirm();
    await pending;
    expect(storage.save).toHaveBeenCalledTimes(1);
    expect(prisma.material.create).toHaveBeenCalledTimes(1);
  });

  it('espera la confirmación de MinIO antes de escribir en PostgreSQL', async () => {
    let confirm!: (result: { storageKey: string }) => void;
    storage.save.mockImplementation(
      () => new Promise((resolve) => { confirm = resolve; }),
    );
    const pending = useCase.execute(input, author, file);
    await new Promise<void>((resolve) => setImmediate(resolve));
    expect(storage.save).toHaveBeenCalled();
    expect(prisma.material.create).not.toHaveBeenCalled();
    confirm({ storageKey: 'materials/confirmed' });
    await pending;
    expect(prisma.material.create).toHaveBeenCalledTimes(1);
  });

  it('persiste LINK sin escribir MinIO ni crear una versión de archivo', async () => {
    const result = await useCase.execute(
      { ...input, type: 'LINK', externalLink: 'https://example.com/note' }, author,
    );
    expect(catalog.validateReferences).toHaveBeenCalledTimes(1);
    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.material.create.mock.calls[0][0].data.versions).toBeUndefined();
    expect(result.data.externalLink).toBe('https://example.com/note');
    expect(result.data.fileSize).toBeNull();
  });

  it('conserva el enlace de respaldo de un archivo', async () => {
    const result = await useCase.execute(
      { ...input, externalLink: 'https://example.com/backup' }, author, file,
    );
    expect(result.data.externalLink).toBe('https://example.com/backup');
  });

  it('rechaza referencias inválidas con 400 sin almacenar ni persistir', async () => {
    catalog.validateReferences.mockRejectedValue(
      new InvalidAcademicReferenceError('subjectId', 'La asignatura no existe o está inactiva.'),
    );
    await expect(useCase.execute(input, author, file)).rejects.toThrow(BadRequestException);
    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.material.create).not.toHaveBeenCalled();
    expect(storage.remove).not.toHaveBeenCalled();
  });

  it('devuelve 502 si Catalog no está disponible sin almacenar ni persistir', async () => {
    catalog.validateReferences.mockRejectedValue(new CatalogUnavailableError());
    await expect(useCase.execute(input, author, file)).rejects.toThrow(BadGatewayException);
    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.material.create).not.toHaveBeenCalled();
    expect(storage.remove).not.toHaveBeenCalled();
  });

  it('no crea ningún registro si falla MinIO y oculta el error interno', async () => {
    storage.save.mockRejectedValue(new Error('private endpoint and credentials'));
    await expect(useCase.execute(input, author, file)).rejects.toThrow(BadGatewayException);
    expect(prisma.material.create).not.toHaveBeenCalled();
  });

  it('no informa éxito si falla la persistencia', async () => {
    prisma.material.create.mockRejectedValue(new Error('database unavailable'));
    await expect(useCase.execute(input, author, file)).rejects.toThrow('database unavailable');
  });

  it('rechaza tipo inexistente/inactivo antes de escribir un archivo', async () => {
    prisma.materialType.findFirst.mockResolvedValue(null);
    await expect(useCase.execute(input, author, file)).rejects.toThrow(BadRequestException);
    expect(catalog.validateReferences).not.toHaveBeenCalled();
    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.material.create).not.toHaveBeenCalled();
  });

  it('rechaza combinaciones inválidas antes de acceder a dependencias', async () => {
    await expect(useCase.execute(input, author)).rejects.toThrow(BadRequestException);
    await expect(useCase.execute({ ...input, type: 'LINK' }, author)).rejects.toThrow(
      BadRequestException,
    );
    await expect(useCase.execute(
      { ...input, type: 'LINK', externalLink: 'https://example.com' }, author, file,
    )).rejects.toThrow(BadRequestException);
    expect(prisma.materialType.findFirst).not.toHaveBeenCalled();
    expect(catalog.validateReferences).not.toHaveBeenCalled();
    expect(storage.save).not.toHaveBeenCalled();
    expect(prisma.material.create).not.toHaveBeenCalled();
  });

  const rollback = () => new Prisma.PrismaClientKnownRequestError('rollback', {
    code: 'P2003', clientVersion: '6.12.0',
  });

  it('elimina solo la clave subida tras rechazo confirmado y sin referencia', async () => {
    const error = rollback();
    prisma.material.create.mockRejectedValue(error);
    await expect(useCase.execute(input, author, file)).rejects.toBe(error);
    expect(prisma.materialVersion.findFirst).toHaveBeenCalledWith({
      where: { storageKey: 'materials/internal-key' }, select: { id: true },
    });
    expect(storage.remove).toHaveBeenCalledWith('materials/internal-key');
  });

  it('conserva archivos referenciados aunque haya un error', async () => {
    prisma.material.create.mockRejectedValue(rollback());
    prisma.materialVersion.findFirst.mockResolvedValue({ id: 'existing' });
    await expect(useCase.execute(input, author, file)).rejects.toThrow();
    expect(storage.remove).not.toHaveBeenCalled();
  });

  it('no borra si el commit es incierto aunque una lectura pudiera no encontrarlo aún', async () => {
    prisma.material.create.mockRejectedValue(new Error('connection lost'));
    await expect(useCase.execute(input, author, file)).rejects.toThrow();
    expect(prisma.materialVersion.findFirst).not.toHaveBeenCalled();
    expect(storage.remove).not.toHaveBeenCalled();
    expect(Logger.prototype.warn).toHaveBeenCalled();
  });

  it.each(['lookup', 'remove'])(
    'preserva el error original cuando falla %s y registra limpieza pendiente',
    async (operation) => {
      const error = rollback();
      prisma.material.create.mockRejectedValue(error);
      if (operation === 'lookup') {
        prisma.materialVersion.findFirst.mockRejectedValue(new Error('db unavailable'));
      } else {
        storage.remove.mockRejectedValue(new Error('storage unavailable'));
      }
      await expect(useCase.execute(input, author, file)).rejects.toBe(error);
      if (operation === 'lookup') expect(storage.remove).not.toHaveBeenCalled();
      expect(Logger.prototype.warn).toHaveBeenCalled();
    },
  );

  it('no intenta limpiar LINK ni fallos de subida', async () => {
    prisma.material.create.mockRejectedValue(rollback());
    await expect(useCase.execute(
      { ...input, type: 'LINK', externalLink: 'https://example.com' }, author,
    )).rejects.toThrow();
    expect(storage.remove).not.toHaveBeenCalled();
    storage.save.mockRejectedValue(new Error('write failed'));
    await expect(useCase.execute(input, author, file)).rejects.toThrow();
    expect(storage.remove).not.toHaveBeenCalled();
  });
});
