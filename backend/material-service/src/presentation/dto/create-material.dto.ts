import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsOptional, IsEnum, IsNotEmpty, Matches } from 'class-validator';

export enum MaterialType {
  DOCUMENT = 'DOCUMENT',
  PRESENTATION = 'PRESENTATION',
  LINK = 'LINK',
  EXAM = 'EXAM',
  SUMMARY = 'SUMMARY',
}

export class CreateMaterialDto {
  @ApiProperty({ 
    description: 'OBLIGATORIO. Título descriptivo del recurso.', 
    example: 'Guía Práctica de Álgebra Lineal' 
  })
  @IsString()
  @IsNotEmpty()
  title!: string;

  @ApiPropertyOptional({ 
    description: 'OPCIONAL. Descripción o detalles adicionales del material.', 
    example: 'Ejercicios resueltos sobre valores y vectores propios.' 
  })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ 
    description: 'OBLIGATORIO. Año académico de publicación (Formato YYYY de 4 dígitos).', 
    example: '2026' 
  })
  @IsString()
  @Matches(/^(19|20)\d{2}$/, { message: 'year debe ser un año válido de 4 dígitos (ej. 2026)' })
  year!: string;

  @ApiProperty({ 
    enum: MaterialType, 
    description: 'OBLIGATORIO. Clasificación del material. Determina si se requiere archivo o enlace.', 
    example: MaterialType.DOCUMENT 
  })
  @IsEnum(MaterialType)
  type!: MaterialType;

  @ApiProperty({ 
    description: 'OBLIGATORIO. Identificador académico único de la asignatura asociada.', 
    example: 'SUBJ-102' 
  })
  @IsString()
  @IsNotEmpty()
  subjectId!: string;

  @ApiPropertyOptional({ 
    description: 'OPCIONAL. Identificador académico de la carrera o programa.', 
    example: 'CAREER-INF-01' 
  })
  @IsOptional()
  @IsString()
  careerId?: string;

  @ApiPropertyOptional({ 
    description: 'OPCIONAL. Nombre o ID del profesor de la asignatura.', 
    example: 'Dr. Roberto Gómez' 
  })
  @IsOptional()
  @IsString()
  professor?: string;

  @ApiPropertyOptional({ 
    description: 'OPCIONAL / CONDICIONAL. Enlace web externo. Obligatorio si type es LINK o no se envía archivo.', 
    example: 'https://drive.google.com/file/d/xyz/view' 
  })
  @IsOptional()
  @IsString()
  externalLink?: string;

  @ApiPropertyOptional({ 
    type: 'string', 
    format: 'binary', 
    description: 'OPCIONAL / CONDICIONAL. Archivo binary. Máx 15 MB (15,728,640 bytes). Permitidos: .pdf, .doc, .docx, .ppt, .pptx' 
  })
  @IsOptional()
  file?: any;
}