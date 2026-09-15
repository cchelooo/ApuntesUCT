import { IsOptional, IsString, IsUUID, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

export class FilterCatalogDto {
  @IsUUID()
  @IsOptional()
  universityId?: string;

  @IsUUID()
  @IsOptional()
  careerId?: string;

  @IsUUID()
  @IsOptional()
  subjectId?: string;

  @IsUUID()
  @IsOptional()
  professorId?: string;

  @Type(() => Number)
  @IsInt()
  @Min(2000)
  @Max(2100)
  @IsOptional()
  year?: number;

  @IsString()
  @IsOptional()
  type?: string;
}