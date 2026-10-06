import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MaterialType } from './create-material.dto';

export enum MaterialStatus {
  PENDING_REVIEW = 'PENDING_REVIEW',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
}

export class MaterialDataDto {
  @ApiProperty({ example: 'mat_987654321', description: 'Identificador único generado para el material.' })
  id!: string;

  @ApiProperty({ example: 'Guía Práctica de Álgebra Lineal', description: 'Título del material.' })
  title!: string;

  @ApiPropertyOptional({ example: 'Ejercicios resueltos sobre valores y vectores propios.', nullable: true, description: 'Descripción opcional.' })
  description!: string | null;

  @ApiProperty({ example: '2026', description: 'Año académico de 4 dígitos.' })
  year!: string;

  @ApiProperty({ enum: MaterialType, example: MaterialType.DOCUMENT, description: 'Tipo de recurso.' })
  type!: MaterialType;

  @ApiProperty({ enum: MaterialStatus, example: MaterialStatus.PENDING_REVIEW, description: 'Estado inicial del material tras la subida.' })
  status!: MaterialStatus;

  @ApiProperty({ example: 'SUBJ-102', description: 'Identificador único de la asignatura.' })
  subjectId!: string;

  @ApiPropertyOptional({ example: 'CAREER-INF-01', nullable: true, description: 'Identificador de la carrera.' })
  careerId!: string | null;

  @ApiPropertyOptional({ example: 'prof_88321', nullable: true, description: 'Identificador único del profesor (UUID/ID).' })
  professorId!: string | null;

  @ApiPropertyOptional({ example: 'UNIV-UCT-01', description: 'Identificador de la universidad, derivado automáticamente del contexto académico.' })
  universityId!: string;

  @ApiPropertyOptional({ example: 'https://storage.academico.cl/materials/2026/mat_987654321.pdf', nullable: true, description: 'URL pública de descarga del archivo local.' })
  fileUrl!: string | null;

  @ApiPropertyOptional({ example: 2048500, nullable: true, description: 'Tamaño del archivo en bytes.' })
  fileSize!: number | null;

  @ApiPropertyOptional({ example: 'application/pdf', nullable: true, description: 'MIME type del archivo.' })
  mimeType!: string | null;

  @ApiPropertyOptional({ example: null, nullable: true, description: 'URL de enlace externo si aplica.' })
  externalLink!: string | null;

  @ApiProperty({ example: '2026-10-05T14:00:00.000Z', description: 'Marca de tiempo de creación en formato ISO.' })
  createdAt!: string;
}

export class CreateMaterialResponseDto {
  @ApiProperty({ example: 'success' })
  status!: string;

  @ApiProperty({ example: true, description: 'Indica si la respuesta proviene de un contrato simulado (Stub).' })
  isSimulatedResponse!: boolean;

  @ApiProperty({ example: 'Material registrado exitosamente en estado PENDING_REVIEW.' })
  message!: string;

  @ApiProperty({ type: MaterialDataDto })
  data!: MaterialDataDto;
}