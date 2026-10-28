import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export enum SearchSortBy {
  CREATED_AT = 'createdAt',
  TITLE = 'title',
  YEAR = 'year',
}

export enum SearchOrder {
  ASC = 'asc',
  DESC = 'desc',
}

// No convertir arreglos, booleanos ni cadenas vacías en números válidos.
function integerQuery(value: unknown): unknown {
  return typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value;
}

function uuidQuery(value: unknown): unknown {
  return typeof value === 'string' ? value.toLowerCase() : value;
}

export class SearchQueryDto {
  @ApiPropertyOptional({
    description:
      'Coincidencia parcial en título o descripción, sin distinguir mayúsculas ni tildes. Se eliminan espacios exteriores. Vacío o solo espacios equivale a omitir q; los demás filtros siguen aplicándose.',
    example: 'Estructuras de Datos',
    maxLength: 200,
  })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  q?: string;

  @ApiPropertyOptional({
    format: 'uuid',
    description:
      'Universidad del contexto académico activo de Catalog. Primer nivel, sin requisito previo.',
  })
  @Transform(({ value }: { value: unknown }) => uuidQuery(value))
  @IsOptional()
  @IsUUID()
  universityId?: string;

  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Carrera del contexto académico activo. Requiere universityId.',
  })
  @Transform(({ value }: { value: unknown }) => uuidQuery(value))
  @IsOptional()
  @IsUUID()
  careerId?: string;

  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Asignatura activa. Requiere careerId y universityId.',
  })
  @Transform(({ value }: { value: unknown }) => uuidQuery(value))
  @IsOptional()
  @IsUUID()
  subjectId?: string;

  @ApiPropertyOptional({
    format: 'uuid',
    description:
      'Profesor asociado al material y vinculado a la asignatura en Catalog. Requiere subjectId, careerId y universityId.',
  })
  @Transform(({ value }: { value: unknown }) => uuidQuery(value))
  @IsOptional()
  @IsUUID()
  professorId?: string;

  @ApiPropertyOptional({
    type: Number,
    minimum: 1900,
    maximum: 2099,
    example: 2026,
    description:
      'Año académico exacto (1900–2099). Independiente de los filtros académicos y de type.',
  })
  @Transform(({ value }: { value: unknown }) => integerQuery(value))
  @IsOptional()
  @IsInt()
  @Min(1900)
  @Max(2099)
  year?: number;

  @ApiPropertyOptional({
    example: 'DOCUMENT',
    maxLength: 100,
    description:
      'Nombre exacto de materialType publicado por Material (distingue mayúsculas). Se eliminan espacios exteriores. No se limita al enum del POST. Independiente de year y del contexto académico; un nombre sin coincidencias produce total 0.',
  })
  @Transform(({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value))
  @IsOptional()
  @IsString()
  @Matches(/\S/u, { message: 'type debe contener al menos un carácter que no sea espacio' })
  @MaxLength(100)
  type?: string;

  @ApiPropertyOptional({
    enum: SearchSortBy,
    default: SearchSortBy.CREATED_AT,
    description:
      'Campo de ordenamiento. title compara texto normalizado sin mayúsculas ni tildes por orden lexicográfico Unicode. No se admite valoración. Nulos al final; empates por id DESC.',
  })
  @IsOptional()
  @IsEnum(SearchSortBy)
  sortBy: SearchSortBy = SearchSortBy.CREATED_AT;

  @ApiPropertyOptional({
    enum: SearchOrder,
    default: SearchOrder.DESC,
    description: 'Dirección del campo seleccionado. El desempate por id siempre es DESC.',
  })
  @IsOptional()
  @IsEnum(SearchOrder)
  order: SearchOrder = SearchOrder.DESC;

  @ApiPropertyOptional({
    type: Number,
    description: 'Página final de coincidencias, comenzando en 1.',
    default: 1,
    minimum: 1,
    maximum: 2147483647,
  })
  @Transform(({ value }: { value: unknown }) => integerQuery(value))
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(2147483647)
  page: number = 1;

  @ApiPropertyOptional({
    type: Number,
    description: 'Cantidad de resultados por página.',
    default: 20,
    minimum: 1,
    maximum: 100,
  })
  @Transform(({ value }: { value: unknown }) => integerQuery(value))
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize: number = 20;
}
