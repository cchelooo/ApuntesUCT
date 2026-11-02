import { ApiProperty } from '@nestjs/swagger';

export class SearchProfessorDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  name: string;
}

export class SearchSubjectContextDto {
  @ApiProperty()
  subjectId: string;

  @ApiProperty()
  subjectName: string;

  @ApiProperty({ nullable: true, type: String })
  subjectCode: string | null;

  @ApiProperty({ nullable: true, type: Number })
  semester: number | null;

  @ApiProperty({ nullable: true, type: String })
  careerId: string | null;

  @ApiProperty({ nullable: true, type: String })
  careerName: string | null;

  @ApiProperty({ nullable: true, type: String })
  universityId: string | null;

  @ApiProperty({ nullable: true, type: String })
  universityName: string | null;

  @ApiProperty({ type: [SearchProfessorDto] })
  professors: SearchProfessorDto[];
}

export class SearchResultDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  title: string;

  @ApiProperty({ nullable: true, type: String })
  description: string | null;

  @ApiProperty({ nullable: true, type: String })
  materialType: string | null;

  @ApiProperty({ nullable: true, type: Number })
  academicYear: number | null;

  @ApiProperty()
  verified: boolean;

  @ApiProperty({ nullable: true, type: String })
  subjectId: string | null;

  @ApiProperty({ nullable: true, type: String })
  careerId: string | null;

  @ApiProperty({ nullable: true, type: String })
  universityId: string | null;

  @ApiProperty({ nullable: true, type: String })
  professorId: string | null;

  @ApiProperty({ nullable: true, type: String })
  subjectName: string | null;

  @ApiProperty({ nullable: true, type: String })
  careerName: string | null;

  @ApiProperty({ nullable: true, type: String })
  universityName: string | null;

  @ApiProperty({ nullable: true, type: String })
  createdAt: string | null;

  @ApiProperty({ nullable: true, type: String })
  updatedAt: string | null;
}

export class SearchResponseDto {
  @ApiProperty({ nullable: true, type: String })
  query: string | null;

  @ApiProperty()
  page: number;

  @ApiProperty()
  pageSize: number;

  @ApiProperty()
  total: number;

  @ApiProperty({ type: [SearchResultDto] })
  results: SearchResultDto[];

  @ApiProperty({ type: [SearchSubjectContextDto] })
  context: SearchSubjectContextDto[];
}
