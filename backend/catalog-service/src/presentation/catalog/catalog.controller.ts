import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { CatalogService } from '../../application/services/catalog.service';
import { FilterCatalogDto } from '../../application/dtos/filter-catalog.dto';
import { UniversityResponseDto } from '../../application/dtos/catalog-response.dto';

@ApiTags('Catalog')
@Controller('catalog')
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get()
  @ApiOperation({
    summary: 'Obtener árbol básico del catálogo',
    description:
      'Devuelve la jerarquía base completa del catálogo (Universidades -> Carreras -> Asignaturas) para ser consumida de forma inicial por el frontend.',
  })
  @ApiResponse({
    status: 200,
    description: 'Estructura en árbol del catálogo consultada exitosamente.',
    type: [UniversityResponseDto],
  })
  async getCatalog(): Promise<UniversityResponseDto[]> {
    return this.catalogService.getCatalogTree();
  }

  @Get('filter')
  @ApiOperation({
    summary: 'Filtrar catálogo jerárquico de asignaturas',
    description: `
    Realiza una búsqueda jerárquica devolviendo las asignaturas coincidentes junto con sus relaciones principales.

    ### Comportamiento del Endpoint:
    - **Sin filtros:** Devuelve la lista completa de **Asignaturas**.
    - **Filtros válidos aplicados:** Devuelve las asignaturas filtradas incluyendo sus relaciones directas (**Carrera**, **Universidad** y **Profesores**).
    - **Combinación incompatible:** Devuelve un arreglo vacío (\`[]\`).

    ### Secuencia Obligatoria de Niveles:
    1. **Universidad** (\`universityId\`)
    2. **Carrera** (\`careerId\`) [requiere \`universityId\`]
    3. **Asignatura** (\`subjectId\`) [requiere \`careerId\`]
    4. **Profesor** (\`professorId\`) [requiere \`subjectId\`]
    5. **Año** (\`year\`) [requiere \`professorId\`]
    6. **Tipo** (\`type\`) [requiere \`year\`]

    ### Estado de los Filtros de Año y Tipo:
    Los niveles de **Año** (\`year\`) y **Tipo** (\`type\`) requieren la integración del módulo de **Recursos**. Al enviar una secuencia válida que incluya estos parámetros, el endpoint retornará un estado **501 Not Implemented** indicando que la funcionalidad de filtrado de recursos está pendiente de implementación.
    `,
  })
  @ApiResponse({
    status: 200,
    description:
      'Lista de asignaturas que cumplen con el filtro, incluyendo Carrera, Universidad y Profesores.',
  })
  @ApiResponse({
    status: 400,
    description: 'Error si se rompe la secuencia obligatoria de filtrado.',
  })
  @ApiResponse({
    status: 501,
    description:
      'Funcionalidad no implementada. Se retorna cuando se envían los parámetros Año/Tipo debido a la dependencia pendiente con el módulo de Recursos.',
  })
  async filterCatalog(@Query() filters: FilterCatalogDto) {
    return this.catalogService.filterCatalog(filters);
  }
}
