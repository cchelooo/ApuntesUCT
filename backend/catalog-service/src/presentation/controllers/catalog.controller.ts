import { Controller, Get, Query } from '@nestjs/common';
import { CatalogService } from '../../application/services/catalog.service';
import { FilterCatalogDto } from '../../application/dtos/filter-catalog.dto';

@Controller('catalog')
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get('filter')
  async filter(@Query() filters: FilterCatalogDto) {
    return this.catalogService.filterCatalog(filters);
  }
}