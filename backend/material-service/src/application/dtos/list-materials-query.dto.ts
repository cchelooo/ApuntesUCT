import { Transform } from 'class-transformer';
import { IsInt, Max, Min } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

// Accept decimal integers only; arrays, blank strings and scientific notation are invalid.
const decimalInteger = ({ value }: { value: unknown }) =>
  typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value;

export class ListMaterialsQueryDto {
  @ApiPropertyOptional({ default: 1, minimum: 1, maximum: 2147483647, type: Number })
  @Transform(decimalInteger)
  @IsInt()
  @Min(1)
  @Max(2147483647)
  page: number = 1;

  @ApiPropertyOptional({ default: 20, minimum: 1, maximum: 100, type: Number })
  @Transform(decimalInteger)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize: number = 20;
}
