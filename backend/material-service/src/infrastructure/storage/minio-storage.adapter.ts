import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import type { Readable } from 'node:stream';
import { Client, S3Error } from 'minio';
import {
  ObjectNotFoundError,
  ObjectStorage,
  ObjectStorageError,
  StoredObject,
} from '../../application/ports/object-storage.port';
import { readMinioConfig } from './minio.config';

@Injectable()
export class MinioStorageAdapter extends ObjectStorage {
  private connection?: { client: Client; bucket: string };

  constructor(private readonly config: ConfigService) {
    super();
  }

  async save(content: Buffer, contentType: string): Promise<StoredObject> {
    try {
      const { client, bucket } = this.getConnection();
      const storageKey = `materials/${randomUUID()}`;
      await client.putObject(bucket, storageKey, content, content.length, {
        'Content-Type': contentType,
      });
      return { storageKey };
    } catch {
      // Los errores del SDK pueden incluir endpoint, bucket y datos de la petición.
      throw new ObjectStorageError();
    }
  }

  async get(storageKey: string): Promise<Readable> {
    try {
      const { client, bucket } = this.getConnection();
      return await client.getObject(bucket, storageKey);
    } catch (error) {
      if (error instanceof S3Error) {
        const { code } = error;
        if (code === 'NoSuchKey' || code === 'NoSuchBucket' || code === 'NotFound') {
          throw new ObjectNotFoundError();
        }
      }
      throw new ObjectStorageError();
    }
  }

  async remove(storageKey: string): Promise<void> {
    try {
      const { client, bucket } = this.getConnection();
      await client.removeObject(bucket, storageKey);
    } catch {
      throw new ObjectStorageError();
    }
  }

  private getConnection() {
    // Inicialización diferida: los endpoints de consulta no requieren MinIO.
    if (!this.connection) {
      const options = readMinioConfig(this.config);
      this.connection = { client: new Client(options.client), bucket: options.bucket };
    }
    return this.connection;
  }
}
