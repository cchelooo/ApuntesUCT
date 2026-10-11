import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { Client } from 'minio';
import {
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
      // Inicialización diferida: los endpoints de consulta no requieren MinIO.
      if (!this.connection) {
        const options = readMinioConfig(this.config);
        this.connection = { client: new Client(options.client), bucket: options.bucket };
      }
      const { client, bucket } = this.connection;
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
}
