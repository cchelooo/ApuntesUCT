import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { HealthCheck, HealthCheckService, HealthCheckResult } from '@nestjs/terminus';

@ApiTags('Health')
@Controller('api/v1/health')
export class HealthController {
  constructor(private readonly health: HealthCheckService) {}

  @Get()
  @HealthCheck()
  @ApiOperation({ summary: 'Verificar el estado de salud de search-service' })
  @ApiResponse({ status: 200, description: 'El servicio está operativo.' })
  check(): Promise<HealthCheckResult> {
    return this.health.check([]);
  }
}