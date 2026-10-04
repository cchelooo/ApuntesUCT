import {
  IsOptional,
  IsUUID,
  IsInt,
  IsEnum,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ResourceType } from '@prisma/client';

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

  /**
 * Debe coincidir con el enum `ResourceType` de la base de datos: un valor
 * fuera del enum nunca podría encontrar recursos, así que se rechaza con 400
 * en lugar de devolver silenciosamente un arreglo vacío.
 */
@IsEnum(ResourceType, {
  message: `type debe ser uno de: ${Object.values(ResourceType).join(', ')}`,
})
@IsOptional()
type?: ResourceType;
}
