import { Controller, Get, Post, Delete, Param, Body, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { CatalogService } from '../../application/services/catalog.service';
import { FilterCatalogDto } from '../../application/dtos/filter-catalog.dto';
import {
  CareerResponseDto,
  ProfessorResponseDto,
  SubjectResponseDto,
  UniversityResponseDto,
} from '../../application/dtos/catalog-response.dto';
import { CreateSubjectDto } from '../../application/dtos/create-subject.dto';
import { CreateUniversityDto } from '../../application/dtos/create-university.dto';
import { CreateCareerDto } from '../../application/dtos/create-career.dto';
import { CreateProfessorDto } from '../../application/dtos/create-professor.dto';
import { ListCareersQueryDto } from '../../application/dtos/list-careers-query.dto';
import { ListSubjectsQueryDto } from '../../application/dtos/list-subjects-query.dto';
import { ListProfessorsQueryDto } from '../../application/dtos/list-professors-query.dto';

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

    ### Alcance del Dominio:
    Catalog solo modela la jerarquía hasta **Profesor**. El filtrado por **Año**
    (\`year\`) y **Tipo** (\`type\`) **no** forma parte de este contrato: los
    metadatos de los materiales pertenecen a **Material Service** y la búsqueda
    por año/tipo corresponde a **Search Service**. Cualquier parámetro ajeno a los
    cuatro niveles anteriores se ignora.
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
      'Error si se rompe la secuencia obligatoria de filtrado (niveles 1 al 4).',
  })
  async filterCatalog(@Query() filters: FilterCatalogDto) {
    return this.catalogService.filterCatalog(filters);
  }

  // =========================================================================
  // ENDPOINTS DE LISTADO PARA LOS SELECTORES ACADÉMICOS
  // =========================================================================

  @Get('universities')
  @ApiOperation({
    summary: 'Listar universidades activas',
    description:
      'Devuelve las universidades activas ordenadas por nombre. Alimenta el selector de universidades del frontend.',
  })
  @ApiResponse({
    status: 200,
    description: 'Listado de universidades activas.',
    type: [UniversityResponseDto],
  })
  async listUniversities(): Promise<UniversityResponseDto[]> {
    return this.catalogService.listUniversities();
  }

  @Get('careers')
  @ApiOperation({
    summary: 'Listar carreras activas',
    description:
      'Devuelve las carreras activas ordenadas por nombre. Permite acotar el resultado a una universidad con `universityId`.',
  })
  @ApiResponse({
    status: 200,
    description: 'Listado de carreras activas.',
    type: [CareerResponseDto],
  })
  @ApiResponse({ status: 400, description: '`universityId` no es un UUID válido.' })
  async listCareers(
    @Query() query: ListCareersQueryDto,
  ): Promise<CareerResponseDto[]> {
    return this.catalogService.listCareers(query.universityId);
  }

  @Get('subjects')
  @ApiOperation({
    summary: 'Listar asignaturas activas',
    description:
      'Devuelve las asignaturas activas ordenadas por nombre. Permite acotar el resultado a una carrera con `careerId`.',
  })
  @ApiResponse({
    status: 200,
    description: 'Listado de asignaturas activas.',
    type: [SubjectResponseDto],
  })
  @ApiResponse({ status: 400, description: '`careerId` no es un UUID válido.' })
  async listSubjects(
    @Query() query: ListSubjectsQueryDto,
  ): Promise<SubjectResponseDto[]> {
    return this.catalogService.listSubjects(query.careerId);
  }

  @Get('professors')
  @ApiOperation({
    summary: 'Listar profesores activos',
    description:
      'Devuelve los profesores activos ordenados por nombre. Permite acotar el resultado a quienes dictan una asignatura con `subjectId`.',
  })
  @ApiResponse({
    status: 200,
    description: 'Listado de profesores activos.',
    type: [ProfessorResponseDto],
  })
  @ApiResponse({ status: 400, description: '`subjectId` no es un UUID válido.' })
  async listProfessors(
    @Query() query: ListProfessorsQueryDto,
  ): Promise<ProfessorResponseDto[]> {
    return this.catalogService.listProfessors(query.subjectId);
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