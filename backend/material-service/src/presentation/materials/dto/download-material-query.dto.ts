import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

export class DownloadMaterialQueryDto {
  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Versión específica a descargar; por defecto se resuelve la última del material.',
  })
  @IsOptional()
  @IsUUID()
  versionId?: string;
}