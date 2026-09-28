import { Controller, Get, Header } from '@nestjs/common';
import {
  ApiOkResponse,
  ApiOperation,
  ApiProperty,
  ApiTags,
} from '@nestjs/swagger';

export class HealthResponse {
  @ApiProperty({ example: 'ok', enum: ['ok'] })
  status: 'ok';

  @ApiProperty({ example: 'API Gateway' })
  service: string;

  @ApiProperty({ example: '2026-09-13T12:00:00.000Z', format: 'date-time' })
  timestamp: string;
}

@ApiTags('health')
@Controller(['health', 'api/v1/health'])
export class HealthController {
  @Get()
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary: 'Verifica que el API Gateway está operativo',
    description:
      'Chequeo público de disponibilidad del Gateway. No consulta bases de datos ni otros microservicios.',
  })
  @ApiOkResponse({ type: HealthResponse })
  check(): HealthResponse {
    return {
      status: 'ok',
      service: 'API Gateway',
      timestamp: new Date().toISOString(),
    };
  }
}
