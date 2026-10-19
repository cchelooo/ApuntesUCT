import { ApiProperty } from '@nestjs/swagger';

export class MaterialCurrentVersionDto {
  @ApiProperty({ format: 'uuid' })
  id!: string;

  @ApiProperty({ minimum: 1 })
  versionNumber!: number;

  @ApiProperty()
  originalFilename!: string;

  @ApiProperty()
  mimeType!: string;

  @ApiProperty({
    type: String,
    example: '15728640',
    description: 'Tamaño en bytes como cadena decimal para preservar la precisión de BigInt.',
  })
  fileSize!: string;

  @ApiProperty({ type: String, format: 'date-time' })
  createdAt!: string;
}

export class MaterialDetailDto {
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

  @ApiProperty()
  academicYear!: number;

  @ApiProperty({ enum: ['PUBLISHED'] })
  status!: 'PUBLISHED';

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
}
