import { ApiProperty } from '@nestjs/swagger';

export class HealthResponseDto {
  @ApiProperty({ enum: ['ok', 'error'], example: 'ok' })
  status: 'ok' | 'error';
  @ApiProperty({ enum: ['quality-service'], example: 'quality-service' })
  service: 'quality-service';
  @ApiProperty({ enum: ['up', 'down'], example: 'up' })
  database: 'up' | 'down';
}
