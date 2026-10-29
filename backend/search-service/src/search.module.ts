import { Module } from '@nestjs/common';
import { CatalogPort } from './application/ports/catalog.port';
import { MaterialPort } from './application/ports/material.port';
import { SearchService } from './application/services/search.service';
import { CatalogHttpAdapter } from './infrastructure/http/catalog-http.adapter';
import { MaterialHttpAdapter } from './infrastructure/http/material-http.adapter';
import { SearchController } from './presentation/controllers/search.controller';

@Module({
  controllers: [SearchController],
  providers: [
    SearchService,
    { provide: CatalogPort, useClass: CatalogHttpAdapter },
    { provide: MaterialPort, useClass: MaterialHttpAdapter },
  ],
})
export class SearchModule {}
