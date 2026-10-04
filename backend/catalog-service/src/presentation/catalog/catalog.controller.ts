import { Controller, Get, Post, Delete, Param, Body, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { CatalogService } from '../../application/services/catalog.service';
import { FilterCatalogDto } from '../../application/dtos/filter-catalog.dto';
import { UniversityResponseDto } from '../../application/dtos/catalog-response.dto';
import { CreateSubjectDto } from '../../application/dtos/create-subject.dto';
import { CreateUniversityDto } from '../../application/dtos/create-university.dto';
import { CreateCareerDto } from '../../application/dtos/create-career.dto';
import { CreateProfessorDto } from '../../application/dtos/create-professor.dto';

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
    Los niveles de **Año** (\`year\`) y **Tipo** (\`type\`) se resuelven contra
    **Resource**, que es una relación de la asignatura dentro del dominio de
    Catalog. La respuesta sigue siendo una lista de **Asignaturas**: la asignatura
    solo se incluye si tiene al menos un recurso activo que coincida con el año y,
    cuando se envía, con el tipo.

    Catalog **no** devuelve el payload de los recursos. Los archivos, las
    versiones y las descargas pertenecen a **Material Service**, que aún no está
    implementado. Por lo tanto, usar \`year\` o \`type\` con un valor fuera del
    enum \`ResourceType\` devuelve **400 Bad Request** en lugar de un arreglo vacío.
    `,
  })
  @ApiResponse({
    status: 200,
    description:
      'Lista de asignaturas que cumplen con el filtro, incluyendo Carrera, Universidad y Profesores.',
  })
  @ApiResponse({
    status: 400,
    description:
      'Error si se rompe la secuencia obligatoria de filtrado o si `type` no pertenece al enum ResourceType.',
  })
  async filterCatalog(@Query() filters: FilterCatalogDto) {
    return this.catalogService.filterCatalog(filters);
  }

  // =========================================================================
  // ENDPOINTS DE GESTIÓN DEL CATÁLOGO
  // =========================================================================

  @Post('universities')
  @ApiOperation({ summary: 'Crear nueva universidad' })
  @ApiResponse({ status: 201, description: 'Universidad creada exitosamente.' })
  @ApiResponse({ status: 400, description: 'Datos de entrada inválidos.' })
  @ApiResponse({
    status: 409,
    description: 'Conflicto: Ya existe una universidad con el mismo código.',
  })
  async createUniversity(@Body() createUniversityDto: CreateUniversityDto) {
    return this.catalogService.createUniversity(createUniversityDto);
  }

  @Delete('universities/:id')
  @ApiOperation({
    summary: 'Eliminar una universidad por ID',
    description:
      'Elimina en cascada sus carreras, asignaturas y recursos asociados.',
  })
  @ApiResponse({ status: 200, description: 'Universidad eliminada exitosamente.' })
  @ApiResponse({ status: 404, description: 'La universidad especificada no existe.' })
  async deleteUniversity(@Param('id') id: string) {
    return this.catalogService.deleteUniversity(id);
  }

  @Post('careers')
  @ApiOperation({ summary: 'Crear nueva carrera' })
  @ApiResponse({ status: 201, description: 'Carrera creada exitosamente.' })
  @ApiResponse({ status: 400, description: 'Datos de entrada inválidos.' })
  @ApiResponse({ status: 404, description: 'La universidad especificada no existe.' })
  @ApiResponse({
    status: 409,
    description:
      'Conflicto: Ya existe una carrera con el mismo código en esa universidad.',
  })
  async createCareer(@Body() createCareerDto: CreateCareerDto) {
    return this.catalogService.createCareer(createCareerDto);
  }

  @Delete('careers/:id')
  @ApiOperation({
    summary: 'Eliminar una carrera por ID',
    description: 'Elimina en cascada sus asignaturas y recursos asociados.',
  })
  @ApiResponse({ status: 200, description: 'Carrera eliminada exitosamente.' })
  @ApiResponse({ status: 404, description: 'La carrera especificada no existe.' })
  async deleteCareer(@Param('id') id: string) {
    return this.catalogService.deleteCareer(id);
  }

  @Post('professors')
  @ApiOperation({
    summary: 'Crear nuevo profesor',
    description:
      'Opcionalmente vincula el profesor a una o más asignaturas mediante `subjectIds`.',
  })
  @ApiResponse({ status: 201, description: 'Profesor creado exitosamente.' })
  @ApiResponse({ status: 400, description: 'Datos de entrada inválidos.' })
  @ApiResponse({
    status: 404,
    description: 'Alguna de las asignaturas indicadas no existe.',
  })
  @ApiResponse({
    status: 409,
    description: 'Conflicto: Ya existe un profesor con el mismo correo.',
  })
  async createProfessor(@Body() createProfessorDto: CreateProfessorDto) {
    return this.catalogService.createProfessor(createProfessorDto);
  }

  @Delete('professors/:id')
  @ApiOperation({
    summary: 'Eliminar un profesor por ID',
    description:
      'Desvincula al profesor de sus asignaturas y deja sus recursos sin profesor asociado.',
  })
  @ApiResponse({ status: 200, description: 'Profesor eliminado exitosamente.' })
  @ApiResponse({ status: 404, description: 'El profesor especificado no existe.' })
  async deleteProfessor(@Param('id') id: string) {
    return this.catalogService.deleteProfessor(id);
  }

  @Post('subjects')
  @ApiOperation({ summary: 'Crear nueva asignatura' })
  @ApiResponse({ status: 201, description: 'Asignatura creada exitosamente.' })
  @ApiResponse({ status: 400, description: 'Datos de entrada inválidos.' })
  @ApiResponse({ status: 404, description: 'La carrera especificada no existe.' })
  @ApiResponse({
    status: 409,
    description: 'Conflicto: Ya existe una asignatura con el mismo código en esta carrera.',
  })
  async createSubject(@Body() createSubjectDto: CreateSubjectDto) {
    return this.catalogService.createSubject(createSubjectDto);
  }

  @Delete('subjects/:id')
  @ApiOperation({ summary: 'Eliminar una asignatura por ID' })
  @ApiResponse({ status: 200, description: 'Asignatura eliminada exitosamente.' })
  @ApiResponse({ status: 404, description: 'La asignatura especificada no existe.' })
  async deleteSubject(@Param('id') id: string) {
    return this.catalogService.deleteSubject(id);
  }
}