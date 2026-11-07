import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import {
  ApiOkResponse,
  ApiOperation,
  ApiServiceUnavailableResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CheckQualityHealth } from '../../application/check-quality-health';
import { HealthResponseDto } from '../dtos/health-response.dto';

@ApiTags('Health')
@Controller('health')
export class HealthController {
  constructor(private readonly checkHealth: CheckQualityHealth) {}
  @Get()
  @ApiOperation({
    summary: 'Comprobar salud de Quality y conexión a quality_db',
    description: 'Ejecuta SELECT 1 en la base propia. No consulta Auth, Material ni sus tablas.',
  })
  @ApiOkResponse({ type: HealthResponseDto })
  @ApiServiceUnavailableResponse({
    type: HealthResponseDto,
    description: 'Base de Quality no disponible.',
  })
  async check(): Promise<HealthResponseDto> {
    const result = await this.checkHealth.execute();
    if (result.status === 'error') throw new ServiceUnavailableException(result);
    return result;
  }
}
