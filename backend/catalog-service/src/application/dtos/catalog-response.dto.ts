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

  @ApiPropertyOptional()
  description?: string;

  @ApiProperty()
  active!: boolean;

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