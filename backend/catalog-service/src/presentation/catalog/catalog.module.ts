import { Module } from '@nestjs/common';
import { CatalogController } from './catalog.controller';
import { CatalogService } from '../../application/services/catalog.service';

@Module({
  controllers: [CatalogController],
  providers: [CatalogService],
  exports: [CatalogService],
})
export class CatalogModule {}
