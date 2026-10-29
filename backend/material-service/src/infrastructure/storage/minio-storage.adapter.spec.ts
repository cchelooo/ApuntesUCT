import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { Readable } from 'node:stream';
import { Client, S3Error } from 'minio';
import {
  ObjectNotFoundError,
  ObjectStorage,
  ObjectStorageError,
} from '../../application/ports/object-storage.port';
import { MinioStorageAdapter } from './minio-storage.adapter';
import { StorageModule } from './storage.module';
import { readMinioConfig } from './minio.config';

jest.mock('minio', () => ({
  Client: jest.fn(),
  S3Error: jest.requireActual('minio').S3Error,
}));

const settings = {
  MINIO_ENDPOINT: 'storage.internal',
  MINIO_PORT: '9000',
  MINIO_USE_SSL: 'false',
  MINIO_BUCKET: 'private-materials',
  MINIO_ACCESS_KEY: 'test-access',
  MINIO_SECRET_KEY: 'test-secret',
};

describe('MinioStorageAdapter', () => {
  const putObject = jest.fn();
  const removeObject = jest.fn();
  const getObject = jest.fn();
  let storage: ObjectStorage;

  beforeEach(async () => {
    removeObject.mockReset().mockResolvedValue(undefined);
    putObject.mockReset().mockResolvedValue({ etag: 'etag' });
    getObject.mockReset();
    jest
      .mocked(Client)
      .mockImplementation(() => ({ putObject, removeObject, getObject }) as unknown as Client);
    const module = await Test.createTestingModule({ imports: [StorageModule] })
      .overrideProvider(ConfigService)
      .useValue(new ConfigService(settings))
      .compile();
    storage = module.get(ObjectStorage);
  });

  it('resuelve el puerto y guarda bytes, tamaño y MIME en el bucket configurado', async () => {
    const content = Buffer.from('%PDF-1.7\n');
    const result = await storage.save(content, 'application/pdf');
    expect(Client).toHaveBeenCalledWith({
      endPoint: 'storage.internal',
      port: 9000,
      useSSL: false,
      accessKey: 'test-access',
      secretKey: 'test-secret',
    });
    expect(putObject).toHaveBeenCalledWith(
      'private-materials',
      result.storageKey,
      content,
      content.length,
      { 'Content-Type': 'application/pdf' },
    );
    expect(result).toEqual({ storageKey: expect.stringMatching(/^materials\/[0-9a-f-]{36}$/) });
  });

  it('genera claves diferentes para contenidos iguales sin aceptar nombres del usuario', async () => {
    const content = Buffer.from('same');
    const [first, second] = await Promise.all([
      storage.save(content, 'application/pdf'),
      storage.save(content, 'application/pdf'),
    ]);
    expect(first.storageKey).not.toBe(second.storageKey);
    expect(Client).toHaveBeenCalledTimes(1);
  });

  it('oculta detalles del SDK y no informa éxito si la escritura falla', async () => {
    putObject.mockRejectedValue(new Error('storage.internal/private-materials test-secret'));
    await expect(storage.save(Buffer.from('x'), 'application/pdf')).rejects.toEqual(
      new ObjectStorageError(),
    );
  });

  it('elimina del bucket configurado sin depender de una subida previa', async () => {
    await storage.remove('materials/uuid');
    expect(removeObject).toHaveBeenCalledWith('private-materials', 'materials/uuid');
  });

  it('oculta detalles internos cuando falla el borrado', async () => {
    removeObject.mockRejectedValue(new Error('private endpoint secret'));
    await expect(storage.remove('materials/uuid')).rejects.toEqual(new ObjectStorageError());
  });

  it('permite instanciar sin configuración pero rechaza guardar sin credenciales', async () => {
    const adapter = new MinioStorageAdapter(
      new ConfigService({ ...settings, MINIO_SECRET_KEY: '' }),
    );
    await expect(adapter.save(Buffer.from('x'), 'application/pdf')).rejects.toEqual(
      new ObjectStorageError(),
    );
    expect(putObject).not.toHaveBeenCalled();
  });

  it('lee el objeto por su clave interna devolviendo el stream exacto', async () => {
    const content = Buffer.from('%PDF-1.7\ntest');
    getObject.mockResolvedValue(Readable.from([content]));
    const stream = await storage.get('materials/1f1c67b4-9c02-4524-b86a-716f5ca1d3c4');
    expect(getObject).toHaveBeenCalledWith('private-materials', 'materials/1f1c67b4-9c02-4524-b86a-716f5ca1d3c4');
    const chunks: Buffer[] = [];
    for await (const chunk of stream) chunks.push(chunk);
    expect(Buffer.concat(chunks)).toEqual(content);
  });

  it('convierte NoSuchKey en ObjectNotFoundError sin exponer la clave', async () => {
    const missing = new S3Error('offline');
    missing.code = 'NoSuchKey';
    getObject.mockRejectedValue(missing);
    await expect(storage.get('materials/desaparecido')).rejects.toEqual(
      new ObjectNotFoundError(),
    );
  });

  it('oculta errores de conexión o permisos como ObjectStorageError', async () => {
    getObject.mockRejectedValue(new S3Error('AccessDenied'));
    await expect(storage.get('materials/1')).rejects.toEqual(new ObjectStorageError());
  });
});

describe('configuración MinIO', () => {
  it('interpreta explícitamente el booleano SSL', () => {
    expect(readMinioConfig(new ConfigService(settings)).client.useSSL).toBe(false);
    expect(
      readMinioConfig(new ConfigService({ ...settings, MINIO_USE_SSL: 'true' })).client.useSSL,
    ).toBe(true);
  });

  it.each([
    ['MINIO_ENDPOINT', 'https://host/path'],
    ['MINIO_PORT', '9000abc'],
    ['MINIO_PORT', '0'],
    ['MINIO_PORT', '65536'],
    ['MINIO_USE_SSL', 'yes'],
    ['MINIO_BUCKET', 'Bad/Bucket'],
    ['MINIO_BUCKET', 'ab'],
    ['MINIO_BUCKET', 'a..b'],
    ['MINIO_ACCESS_KEY', ''],
    ['MINIO_SECRET_KEY', '   '],
  ])('rechaza %s inválido', (name, value) => {
    expect(() => readMinioConfig(new ConfigService({ ...settings, [name]: value }))).toThrow();
  });
});
