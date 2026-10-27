import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiQuery, ApiResponse, ApiTags } from '@nestjs/swagger';
import { SearchQueryDto } from '../../application/dtos/search-query.dto';
import { SearchResponseDto } from '../../application/dtos/search-response.dto';
import { SearchService } from '../../application/services/search.service';

@ApiTags('Search')
@Controller('api/v1/search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get()
  @ApiOperation({
    summary: 'Buscar materiales y recursos',
    description:
      'Compone el listado paginado de Material con el contexto académico resuelto por Catalog. Search no accede a las bases de datos de otros servicios.',
  })
  @ApiQuery({
    name: 'q',
    required: false,
    description: 'Término de búsqueda textual. Se devuelve en `query`.',
    example: 'Estructuras de Datos',
  })
  @ApiQuery({
    name: 'page',
    required: false,
    description: 'Página solicitada, comenzando en 1.',
    example: 1,
  })
  @ApiQuery({
    name: 'pageSize',
    required: false,
    description: 'Cantidad de resultados por página (máximo 100).',
    example: 20,
  })
  @ApiResponse({
    status: 200,
    description: 'Materiales candidatos con su contexto académico.',
    type: SearchResponseDto,
  })
  @ApiResponse({
    status: 400,
    description:
      'La paginación solicitada no es válida para el servicio de materiales.',
  })
  @ApiResponse({
    status: 502,
    description: 'Un servicio dependiente devolvió una respuesta inválida.',
  })
  @ApiResponse({
    status: 503,
    description: 'Un servicio dependiente no está disponible.',
  })
  async search(@Query() query: SearchQueryDto): Promise<SearchResponseDto> {
    return this.searchService.search(query);
  }
}
