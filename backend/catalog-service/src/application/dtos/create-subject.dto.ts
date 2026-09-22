import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class CreateSubjectDto {
  @ApiProperty({
    description: 'ID de la carrera a la que pertenece la asignatura',
    example: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  })
  @IsUUID()
  @IsNotEmpty()
  careerId!: string;

  @ApiProperty({
    description: 'Código único de la asignatura dentro de la carrera',
    example: 'INF-101',
  })
  @IsString()
  @IsNotEmpty()
  code!: string;

  @ApiProperty({
    description: 'Nombre de la asignatura',
    example: 'Estructuras de Datos',
  })
  @IsString()
  @IsNotEmpty()
  name!: string;

  @ApiProperty({
    description: 'Semestre académico correspondiente a la asignatura',
    example: 3,
    minimum: 1,
  })
  @IsInt()
  @Min(1)
  @IsNotEmpty()
  semester!: number;

  @ApiPropertyOptional({
    description: 'Descripción opcional de la asignatura',
    example: 'Curso sobre estructuras de datos lineales y no lineales.',
  })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({
    description: 'Estado de activación de la asignatura',
    default: true,
    example: true,
  })
  @IsBoolean()
  @IsOptional()
  active?: boolean;
}