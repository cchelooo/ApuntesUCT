import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { SearchQueryDto } from '../../application/dtos/search-query.dto';
import { SearchResponseDto } from '../../application/dtos/search-response.dto';
import { SearchService } from '../../application/services/search.service';

@ApiTags('Search')
@Controller('api/v1/search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get()
  @ApiOperation({
    summary: 'Buscar materiales con filtros y ordenamiento',
    description:
      'Endpoint público. Busca coincidencias parciales en título o descripción sin distinguir mayúsculas ni tildes. ' +
      'Todos los filtros se combinan con AND. q vacío o compuesto solo por espacios equivale a omitir el texto. ' +
      'Search consulta los contratos REST de Catalog y Material, sin acceder a bases ajenas. ' +
      '\n\nJerarquía académica: careerId requiere universityId; subjectId requiere careerId y universityId; ' +
      'professorId requiere los tres niveles anteriores. Una secuencia incompleta devuelve 400. ' +
      'Catalog determina el contexto activo y sus relaciones. El profesor también debe ser el asociado al material. ' +
      'Materiales sin contexto verificable o con carrera/universidad contradictorias no coinciden con filtros académicos. ' +
      'Una combinación completa incompatible o sin coincidencias devuelve 200 con total 0, results [] y context []. ' +
      'year y type son independientes: no requieren profesor ni niveles académicos anteriores. ' +
      '\n\nOrden predeterminado: createdAt DESC, id DESC. Se permiten createdAt, title y year, con asc o desc. ' +
      'Nulos al final; desempate siempre por id DESC. Se filtra y ordena antes de calcular el total y paginar. ' +
      'context incluye solo las asignaturas de la página devuelta. La valoración no está implementada. ' +
      '\n\nLímite: toda consulta con texto, filtros o un orden distinto de createdAt DESC recorre hasta ' +
      '10.000 materiales publicados (100 páginas de 100). Si Material informa más de 10.000, devuelve 503, ' +
      'aunque las coincidencias pudieran ser pocas. No se entregan resultados parciales. El listado sin texto ' +
      'ni filtros con orden predeterminado conserva la paginación de Material y no aplica este límite. ' +
      'Las páginas REST no comparten una instantánea: algunos cambios concurrentes detectables producen 502 y requieren reintentar.',
  })
  @ApiResponse({
    status: 200,
    description: 'Coincidencias paginadas y su contexto académico.',
    type: SearchResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Parámetros inválidos o secuencia académica incompleta.',
  })
  @ApiResponse({
    status: 502,
    description:
      'Respuesta inválida de una dependencia o inconsistencia detectada al recorrer las páginas.',
  })
  @ApiResponse({
    status: 503,
    description:
      'Dependencia no disponible o consulta que requiere recorrer más de 10.000 publicados. Mensaje del límite: "La búsqueda supera el límite de materiales que puede procesarse." No se entregan resultados parciales.',
  })
  async search(@Query() query: SearchQueryDto): Promise<SearchResponseDto> {
    return this.searchService.search(query);
  }
}
