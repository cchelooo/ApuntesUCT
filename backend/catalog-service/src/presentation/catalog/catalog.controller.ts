import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { CatalogService } from '../../application/services/catalog.service';
import { FilterCatalogDto } from '../../application/dtos/filter-catalog.dto';

@ApiTags('Catalog')
@Controller('catalog')
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get('filter')
  @ApiOperation({
    summary: 'Filtrar catálogo jerárquico de asignaturas y recursos',
    description: `
    Realiza una búsqueda jerárquica devolviendo las asignaturas coincidentes junto con sus dependencias.
    
    ### Secuencia Obligatoria de Niveles:
    1. **Universidad** (\`universityId\`)
    2. **Carrera** (\`careerId\`) [requiere \`universityId\`]
    3. **Asignatura** (\`subjectId\`) [requiere \`careerId\`]
    4. **Profesor** (\`professorId\`) [requiere \`subjectId\`]
    5. **Año** (\`year\`) [requiere \`professorId\`]
    6. **Tipo** (\`type\`) [requiere \`year\`]

    ### Retorno del Endpoint:
    Devuelve un arreglo de **Asignaturas**, incluyendo sus relaciones directas (Carrera, Universidad, Profesores) y la lista de **Recursos** filtrados por Año y Tipo.
    `,
  })
  @ApiResponse({
    status: 200,
    description: 'Lista de asignaturas y recursos que cumplen con el filtro.',
  })
  @ApiResponse({
    status: 400,
    description: 'Error 400 si se rompe la secuencia obligatoria de filtrado.',
  })
  async filterCatalog(@Query() filters: FilterCatalogDto) {
    return this.catalogService.filterCatalog(filters);
  }
}
