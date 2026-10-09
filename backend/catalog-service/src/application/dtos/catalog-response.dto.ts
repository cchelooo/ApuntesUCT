import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ProfessorResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  email!: string;

  @ApiProperty()
  active!: boolean;
}

export class SubjectResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  code!: string;

  @ApiProperty({
    description: 'Semestre académico correspondiente a la asignatura dentro del plan de estudios',
    example: 3,
    minimum: 1,
    maximum: 12,
  })
  semester!: number;

  @ApiPropertyOptional({ nullable: true })
  description?: string | null;

  @ApiProperty()
  active!: boolean;

  @ApiPropertyOptional({
    description: 'Carrera a la que pertenece la asignatura.',
    format: 'uuid',
  })
  careerId?: string;

  @ApiPropertyOptional({ type: [ProfessorResponseDto] })
  professors?: ProfessorResponseDto[];

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;
}

export class CareerResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  code!: string;

  @ApiProperty()
  active!: boolean;

  @ApiPropertyOptional({
    description: 'Universidad a la que pertenece la carrera.',
    format: 'uuid',
  })
  universityId?: string;

  @ApiPropertyOptional({ type: [SubjectResponseDto] })
  subjects?: SubjectResponseDto[];

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;
}

export class UniversityResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  code!: string;

  @ApiProperty()
  active!: boolean;

  @ApiPropertyOptional({ type: [CareerResponseDto] })
  careers?: CareerResponseDto[];

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;
}