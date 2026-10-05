import { ApiProperty } from '@nestjs/swagger';

export class MaterialSummaryDto {
  @ApiProperty({ format: 'uuid' })
  id: string;

  @ApiProperty()
  title: string;

  @ApiProperty({ type: String, nullable: true })
  description: string | null;

  @ApiProperty({ format: 'uuid' })
  uploaderId: string;

  @ApiProperty({ type: String, nullable: true })
  academicOfferingId: string | null;

  @ApiProperty({ type: String, nullable: true })
  universityId: string | null;

  @ApiProperty({ type: String, nullable: true })
  careerId: string | null;

  @ApiProperty()
  subjectId: string;

  @ApiProperty({ type: String, nullable: true })
  professorId: string | null;

  @ApiProperty({ format: 'uuid' })
  materialTypeId: string;

  @ApiProperty({ description: 'Nombre del tipo de material.' })
  materialType: string;

  @ApiProperty({ type: 'integer' })
  academicYear: number;

  @ApiProperty({ enum: ['PUBLISHED'] })
  status: 'PUBLISHED';

  @ApiProperty()
  verified: boolean;

  @ApiProperty({ format: 'date-time' })
  createdAt: string;

  @ApiProperty({ format: 'date-time' })
  updatedAt: string;
}

export class MaterialPageDto {
  @ApiProperty({ type: [MaterialSummaryDto] })
  items: MaterialSummaryDto[];

  @ApiProperty({ type: 'integer', minimum: 1 })
  page: number;

  @ApiProperty({ type: 'integer', minimum: 1, maximum: 100 })
  pageSize: number;

  @ApiProperty({ type: 'integer', minimum: 0, description: 'Total de materiales publicados.' })
  total: number;
}
