import { Controller, Get, HttpStatus, Res } from '@nestjs/common';
import {
  ApiOkResponse,
  ApiOperation,
  ApiProperty,
  ApiServiceUnavailableResponse,
  ApiTags,
} from '@nestjs/swagger';
import type { Response } from 'express';
import { HealthService } from '../../application/health/health.service';

export class HealthResponse {
  @ApiProperty({ enum: ['ok', 'unavailable'], example: 'ok' })
  status!: 'ok' | 'unavailable';

  @ApiProperty({ example: 'auth-service' })
  service!: string;

  @ApiProperty({ enum: ['connected', 'disconnected'], example: 'connected' })
  database!: 'connected' | 'disconnected';

  @ApiProperty({ example: '2026-09-07T12:00:00.000Z' })
  timestamp!: string;
}

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  @ApiOperation({
    summary: 'Verifica el estado del servicio y su conexión a PostgreSQL',
  })
  @ApiOkResponse({ type: HealthResponse })
  @ApiServiceUnavailableResponse({ type: HealthResponse })
  async check(
    @Res({ passthrough: true }) res: Response,
  ): Promise<HealthResponse> {
    const result = await this.healthService.check();
    if (result.status === 'unavailable') {
      res.status(HttpStatus.SERVICE_UNAVAILABLE);
    }
    return result;
  }
}
