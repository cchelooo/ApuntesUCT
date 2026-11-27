import { ApiProperty } from '@nestjs/swagger';
import { MaterialCurrentVersionDto } from './material-detail.dto';

/** Material pendiente en el listado privado de moderación (#460). */
export class PendingMaterialSummaryDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty()
  title!: string;

  @ApiProperty({ type: String, nullable: true })
  description!: string | null;

  @ApiProperty({ format: 'uuid' })
  uploaderId!: string;

  @ApiProperty({ type: String, nullable: true })
  academicOfferingId!: string | null;

  @ApiProperty({ type: String, nullable: true })
  universityId!: string | null;

  @ApiProperty({ type: String, nullable: true })
  careerId!: string | null;

  @ApiProperty()
  subjectId!: string;

  @ApiProperty({ type: String, nullable: true })
  professorId!: string | null;

  @ApiProperty({ format: 'uuid' })
  materialTypeId!: string;

  @ApiProperty({ description: 'Nombre del tipo de material.' })
  materialType!: string;

  @ApiProperty({ type: 'integer' })
  academicYear!: number;

  @ApiProperty({ enum: ['PENDING_REVIEW'] })
  status!: 'PENDING_REVIEW';

  @ApiProperty()
  verified!: boolean;

  @ApiProperty({ format: 'date-time' })
  createdAt!: string;

  @ApiProperty({ format: 'date-time' })
  updatedAt!: string;
}

export class PendingMaterialPageDto {
  @ApiProperty({ type: [PendingMaterialSummaryDto] })
  items!: PendingMaterialSummaryDto[];

  @ApiProperty({ type: 'integer', minimum: 1 })
  page!: number;

  @ApiProperty({ type: 'integer', minimum: 1, maximum: 100 })
  pageSize!: number;

  @ApiProperty({ type: 'integer', minimum: 0, description: 'Total de materiales pendientes.' })
  total!: number;
}

/** Detalle privado de un material pendiente, sin claves de almacenamiento (#460). */
export class PendingMaterialDetailDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty()
  title!: string;

  @ApiProperty({ type: String, nullable: true })
  description!: string | null;

  @ApiProperty({ format: 'uuid' })
  uploaderId!: string;

  @ApiProperty({ type: String, nullable: true })
  academicOfferingId!: string | null;

  @ApiProperty({ type: String, nullable: true })
  universityId!: string | null;

  @ApiProperty({ type: String, nullable: true })
  careerId!: string | null;

  @ApiProperty()
  subjectId!: string;

  @ApiProperty({ type: String, nullable: true })
  professorId!: string | null;

  @ApiProperty({ format: 'uuid' })
  materialTypeId!: string;

  @ApiProperty({ description: 'Nombre del tipo local del material.' })
  materialType!: string;

  @ApiProperty({ type: 'integer' })
  academicYear!: number;

  @ApiProperty({ enum: ['PENDING_REVIEW'] })
  status!: 'PENDING_REVIEW';

  @ApiProperty()
  verified!: boolean;

  @ApiProperty({ type: String, nullable: true })
  externalLink!: string | null;

  @ApiProperty({ type: String, format: 'date-time' })
  createdAt!: string;

  @ApiProperty({ type: String, format: 'date-time' })
  updatedAt!: string;

  @ApiProperty({
    type: () => MaterialCurrentVersionDto,
    nullable: true,
    description: 'Versión con mayor versionNumber. Un material LINK sin archivo devuelve null.',
  })
  currentVersion!: MaterialCurrentVersionDto | null;

  @ApiProperty({
    type: () => [MaterialCurrentVersionDto],
    description:
      'Historial completo ordenado por versionNumber descendente; vacío para enlaces sin archivo.',
  })
  versions!: MaterialCurrentVersionDto[];
}
