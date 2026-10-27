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
      'Busca texto en el título o la descripción de los materiales. ' +
      'La búsqueda no distingue mayúsculas ni tildes. Si se omite el texto, ' +
      'devuelve el listado paginado. Los resultados se complementan con ' +
      'el contexto académico de Catalog. Search consume los contratos REST ' +
      'de los servicios y no consulta sus bases de datos.',
  })
  @ApiQuery({
    name: 'q',
    required: false,
    description:
      'Texto opcional para buscar en el título o la descripción. ' +
      'Los espacios al inicio y al final se eliminan.',
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
    description: 'Cantidad de resultados por página, entre 1 y 100.',
    example: 20,
  })
  @ApiResponse({
    status: 200,
    description:
      'Resultados paginados y contexto académico de los materiales encontrados.',
    type: SearchResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Los parámetros de búsqueda o paginación no son válidos.',
  })
  @ApiResponse({
    status: 502,
    description:
      'Un servicio dependiente devolvió una respuesta inválida o inconsistente.',
  })
  @ApiResponse({
    status: 503,
    description:
      'Un servicio dependiente no está disponible o se superó el límite de la búsqueda inicial.',
  })
  async search(@Query() query: SearchQueryDto): Promise<SearchResponseDto> {
    return this.searchService.search(query);
  }
}