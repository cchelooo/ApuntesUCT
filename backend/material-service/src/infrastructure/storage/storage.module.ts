import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ObjectStorage } from '../../application/ports/object-storage.port';
import { MinioStorageAdapter } from './minio-storage.adapter';

@Module({
  imports: [ConfigModule],
  providers: [{ provide: ObjectStorage, useClass: MinioStorageAdapter }],
  exports: [ObjectStorage],
})
export class StorageModule {}
