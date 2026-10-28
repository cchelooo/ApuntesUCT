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
      'Busca coincidencias parciales en el título o la descripción de los materiales ' +
      'publicados, sin distinguir mayúsculas ni tildes. Los espacios al inicio y al ' +
      'final del texto se eliminan. ' +
      'Si q se omite, está vacío o contiene solo espacios, devuelve el listado paginado. ' +
      'Los resultados incluyen el contexto académico obtenido de Catalog. ' +
      'Search consume contratos REST y no consulta bases de datos de otros servicios. ' +
      '\n\nLímite de la búsqueda textual: se pueden recorrer como máximo 10.000 ' +
      'materiales publicados, distribuidos en 100 páginas de 100 elementos. ' +
      'Si Material informa más de 10.000 materiales publicados, cualquier consulta ' +
      'con texto devuelve HTTP 503, aunque el texto pudiera coincidir con pocos ' +
      'materiales. No se entregan resultados parciales. ' +
      'Este límite no se aplica al listado sin texto.',
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
      'Un servicio dependiente no está disponible o la búsqueda textual supera ' +
      'el límite de 10.000 materiales publicados. En este último caso se devuelve ' +
      'el mensaje: "La búsqueda supera el límite de materiales que puede procesarse." ' +
      'No se entregan resultados parciales.',
  })
  async search(@Query() query: SearchQueryDto): Promise<SearchResponseDto> {
    return this.searchService.search(query);
  }
}