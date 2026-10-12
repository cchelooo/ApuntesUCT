import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

/**
 * Query del selector de carreras. `universityId` es opcional: sin él se listan
 * las carreras activas de todas las universidades.
 */
export class ListCareersQueryDto {
  @ApiPropertyOptional({
    description: 'Filtra las carreras de una universidad concreta.',
    format: 'uuid',
  })
  @IsUUID()
  @IsOptional()
  universityId?: string;
}