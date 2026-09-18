import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class SubjectResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  name!: string;

  @ApiProperty()
  code!: string;

  @ApiProperty()
  semester!: number;
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
}
