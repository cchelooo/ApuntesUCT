import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class SearchQueryDto {
  @ApiPropertyOptional({
    description:
    'Texto opcional. Busca coincidencias en el título o la descripción, ' +
    'sin distinguir mayúsculas ni tildes. Los espacios al inicio y al final ' +
    'se eliminan. Si se omite o está vacío, devuelve el listado paginado.',
    example: 'Estructuras de Datos',
    maxLength: 200,
  })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  q?: string;

  @ApiPropertyOptional({
    description: 'Página solicitada, comenzando en 1.',
    default: 1,
    minimum: 1,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(2147483647)
  page: number = 1;

  @ApiPropertyOptional({
    description: 'Cantidad de resultados por página.',
    default: 20,
    minimum: 1,
    maximum: 100,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize: number = 20;
}
