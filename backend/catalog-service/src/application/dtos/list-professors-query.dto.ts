import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

/**
 * Query del selector de profesores. `subjectId` es opcional: sin él se listan
 * los profesores activos de todas las asignaturas.
 */
export class ListProfessorsQueryDto {
  @ApiPropertyOptional({
    description: 'Filtra los profesores que dictan una asignatura concreta.',
    format: 'uuid',
  })
  @IsUUID()
  @IsOptional()
  subjectId?: string;
}