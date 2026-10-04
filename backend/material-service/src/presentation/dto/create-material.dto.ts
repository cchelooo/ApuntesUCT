import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsOptional, IsEnum, IsNotEmpty } from 'class-validator';

export enum MaterialType {
  DOCUMENT = 'DOCUMENT',
  PRESENTATION = 'PRESENTATION',
  LINK = 'LINK',
}

export class CreateMaterialDto {
  @ApiProperty({ description: 'Título del material académico', example: 'Guía de Estructuras de Datos' })
  @IsString()
  @IsNotEmpty()
  title!: string;

  @ApiPropertyOptional({ description: 'Descripción opcional del recurso' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({ description: 'Año académico de publicación', example: '2026' })
  @IsString()
  @IsNotEmpty()
  year!: string;

  @ApiProperty({ enum: MaterialType, description: 'Clasificación del formato del material' })
  @IsEnum(MaterialType)
  type!: MaterialType;

  @ApiProperty({ description: 'Identificador único de la asignatura o curso asociado' })
  @IsString()
  @IsNotEmpty()
  subjectId!: string;

  @ApiPropertyOptional({ description: 'Enlace externo. Obligatorio si no se adjunta archivo local' })
  @IsOptional()
  @IsString()
  externalLink?: string;

  @ApiPropertyOptional({ 
    type: 'string', 
    format: 'binary', 
    description: 'Archivo local a subir (Máx 15MB). Formatos: PDF, DOC, DOCX, PPT, PPTX' 
  })
  @IsOptional()
  file?: any;
}