import { ApiProperty } from '@nestjs/swagger';
import { MaterialCurrentVersionDto } from '../../application/dtos/material-detail.dto';

/** Respuesta pública de CreateMaterialVersion; no expone storageKey ni checksum. */
export class MaterialVersionResponseDto extends MaterialCurrentVersionDto {
  @ApiProperty({ format: 'uuid' })
  materialId!: string;

  @ApiProperty({ format: 'uuid' })
  createdBy!: string;
}
