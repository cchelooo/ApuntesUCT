import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery, ApiResponse } from '@nestjs/swagger';

@ApiTags('Search')
@Controller('api/v1/search')
export class SearchController {

  @Get()
  @ApiOperation({ 
    summary: 'Buscar materiales y recursos',
    description: 'Endpoint stub/preparatorio para la búsqueda global. No accede directamente a las tablas de Material o Catalog.' 
  })
  @ApiQuery({ name: 'q', required: false, description: 'Término de búsqueda', example: 'Estructuras de Datos' })
  @ApiResponse({ status: 200, description: 'Resultados de búsqueda (Mock preparatorio para Semana 3).' })
  async search(@Query('q') query?: string) {
    return {
      query: query || null,
      results: [],
      total: 0,
      message: 'Search Service inicializado correctamente. Búsqueda desacoplada lista para Semana 3.'
    };
  }
}