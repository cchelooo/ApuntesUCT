import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsOptional, IsEnum, IsNotEmpty, Matches, IsUrl } from 'class-validator';

export enum MaterialType {
  DOCUMENT = 'DOCUMENT',
  PRESENTATION = 'PRESENTATION',
  LINK = 'LINK',
  EXAM = 'EXAM',
  SUMMARY = 'SUMMARY',
}

/** Public POST codes map to the name of a local MaterialType record. */
export const MATERIAL_TYPE_DESCRIPTION =
  'Código público del tipo de material. Al implementar persistencia, type se resolverá ' +
  'por coincidencia exacta con MaterialType.name de un registro activo y su id se ' +
  'guardará como materialTypeId. GET /materials expone ese id como materialTypeId ' +
  'y el nombre como materialType. Este POST simulado no consulta ni crea tipos en BD. ' +
  'El enum limita los códigos aceptados por este POST, no todos los tipos existentes en el listado.';

export const MATERIAL_MIME_TYPES = [
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
] as const;

export const MATERIAL_FILE_DESCRIPTION =
  'Archivo binario local (máximo 15 MB). Obligatorio para DOCUMENT, PRESENTATION, EXAM y SUMMARY; ' +
  'no admitido para LINK. MIME permitidos: ' +
  MATERIAL_MIME_TYPES.join(', ') +
  '.';

export class CreateMaterialDto {
  @ApiProperty({
    description: 'OBLIGATORIO. Título descriptivo del recurso.',
    example: 'Guía Práctica de Álgebra Lineal',
  })
  @IsString()
  @IsNotEmpty()
  title!: string;

  @ApiPropertyOptional({
    description: 'OPCIONAL. Descripción o detalles adicionales.',
    example: 'Ejercicios resueltos sobre valores y vectores propios.',
  })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiProperty({
    description: 'OBLIGATORIO. Año académico de publicación (Formato YYYY).',
    example: '2026',
  })
  @IsString()
  @Matches(/^(19|20)\d{2}$/, { message: 'year debe ser un año válido de 4 dígitos (ej. 2026)' })
  year!: string;

  @ApiProperty({
    enum: MaterialType,
    description: MATERIAL_TYPE_DESCRIPTION,
    example: MaterialType.DOCUMENT,
  })
  @IsEnum(MaterialType)
  type!: MaterialType;

  @ApiProperty({
    description: 'OBLIGATORIO. Identificador académico único de la asignatura.',
    example: 'SUBJ-102',
  })
  @IsString()
  @IsNotEmpty()
  subjectId!: string;

  @ApiPropertyOptional({
    description: 'OPCIONAL. Identificador académico de la carrera o programa.',
    example: 'CAREER-INF-01',
  })
  @IsOptional()
  @IsString()
  careerId?: string;

  @ApiPropertyOptional({
    description: 'OPCIONAL. Identificador único (ID/UUID) del profesor asignado.',
    example: 'prof_88321',
  })
  @IsOptional()
  @IsString()
  professorId?: string;

  @ApiPropertyOptional({
    description:
      'CONDICIONAL. Enlace web externo válido (URL). Obligatorio si type es LINK. Opcional como respaldo si se envía archivo.',
    example: 'https://drive.google.com/file/d/xyz/view',
  })
  @IsOptional()
  @IsUrl({}, { message: 'externalLink debe ser una URL válida (ej. https://...)' })
  externalLink?: string;

  @ApiPropertyOptional({
    type: 'string',
    format: 'binary',
    description: MATERIAL_FILE_DESCRIPTION,
  })
  @IsOptional()
  file?: Express.Multer.File;
}
