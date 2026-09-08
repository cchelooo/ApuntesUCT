import { Controller, Get } from '@nestjs/common';
import {
  ApiOkResponse,
  ApiOperation,
  ApiProperty,
  ApiTags,
} from '@nestjs/swagger';
import { HealthService } from '../../application/health/health.service';

export class HealthResponse {
  @ApiProperty({ example: 'ok' })
  status: 'ok';

  @ApiProperty({ example: 'catalog-service' })
  service: string;

  @ApiProperty({ example: '2026-09-07T12:00:00.000Z' })
  timestamp: string;
}

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  @ApiOperation({ summary: 'Verifica el estado del servicio' })
  @ApiOkResponse({ type: HealthResponse })
  check(): HealthResponse {
    return this.healthService.check();
  }
}
