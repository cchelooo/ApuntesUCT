import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

export class FilterCatalogDto {
  @ApiPropertyOptional({
    description: 'Nivel 1. Universidad. Sin requisito previo.',
    format: 'uuid',
  })
  @IsUUID()
  @IsOptional()
  universityId?: string;

  @ApiPropertyOptional({
    description: 'Nivel 2. Carrera. Requiere universityId.',
    format: 'uuid',
  })
  @IsUUID()
  @IsOptional()
  careerId?: string;

  @ApiPropertyOptional({
    description: 'Nivel 3. Asignatura. Requiere careerId.',
    format: 'uuid',
  })
  @IsUUID()
  @IsOptional()
  subjectId?: string;

  @ApiPropertyOptional({
    description: 'Nivel 4. Profesor. Requiere subjectId.',
    format: 'uuid',
  })
  @IsUUID()
  @IsOptional()
  professorId?: string;
}