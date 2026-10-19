import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

/**
 * Query del selector de asignaturas. `careerId` es opcional: sin él se listan
 * las asignaturas activas de todas las carreras.
 */
export class ListSubjectsQueryDto {
  @ApiPropertyOptional({
    description: 'Filtra las asignaturas de una carrera concreta.',
    format: 'uuid',
  })
  @IsUUID()
  @IsOptional()
  careerId?: string;
}