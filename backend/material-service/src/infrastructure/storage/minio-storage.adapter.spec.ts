import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { Client } from 'minio';
import { ObjectStorage, ObjectStorageError } from '../../application/ports/object-storage.port';
import { MinioStorageAdapter } from './minio-storage.adapter';
import { StorageModule } from './storage.module';
import { readMinioConfig } from './minio.config';

jest.mock('minio', () => ({ Client: jest.fn() }));

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
  let storage: ObjectStorage;

  beforeEach(async () => {
    putObject.mockReset().mockResolvedValue({ etag: 'etag' });
    jest.mocked(Client).mockImplementation(() => ({ putObject }) as unknown as Client);
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

  it('permite instanciar sin configuración pero rechaza guardar sin credenciales', async () => {
    const adapter = new MinioStorageAdapter(
      new ConfigService({ ...settings, MINIO_SECRET_KEY: '' }),
    );
    await expect(adapter.save(Buffer.from('x'), 'application/pdf')).rejects.toEqual(
      new ObjectStorageError(),
    );
    expect(putObject).not.toHaveBeenCalled();
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
