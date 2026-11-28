import { ReportDto, ReportPageDto, ErrorDto } from './report-openapi';
import {
  Body,
  Controller,
  Get,
  Header,
  Headers,
  Param,
  Patch,
  Post,
  Query,
  Req,
  Res,
  SetMetadata,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiBody,
  ApiHeader,
  ApiOperation,
  ApiTags,
  ApiResponse,
  ApiQuery,
} from '@nestjs/swagger';
import type { Response } from 'express';
import { ReportService } from './report.service';
import { ReportGuard, type ReportRequest } from './report.guard';
import { ReportErrorFilter } from './report-error.filter';
import { createInput, updateInput, pageInput, uuid, reasons } from './report-contract';

@ApiResponse({ status: 400, schema: ErrorDto, description: 'Solicitud inválida.' })
@ApiResponse({
  status: 401,
  schema: ErrorDto,
  description: 'No autenticado; WWW-Authenticate: Bearer.',
})
@ApiResponse({ status: 403, schema: ErrorDto, description: 'Sin permiso o conflicto de autoría.' })
@ApiResponse({ status: 404, schema: ErrorDto, description: 'Recurso no disponible.' })
@ApiResponse({
  status: 409,
  schema: ErrorDto,
  description: 'Conflicto de clave, reporte abierto, fecha o transición.',
})
@ApiResponse({ status: 502, schema: ErrorDto, description: 'Respuesta de dependencia inválida.' })
@ApiResponse({ status: 503, schema: ErrorDto, description: 'Dependencia no disponible.' })
@ApiTags('Quality reports')
@ApiBearerAuth()
@UseGuards(ReportGuard)
@UseFilters(ReportErrorFilter)
@Controller('quality')
export class ReportController {
  constructor(private readonly reports: ReportService) {}
  @ApiResponse({ status: 201, schema: ReportDto, description: 'Reporte creado.' })
  @ApiResponse({ status: 200, schema: ReportDto, description: 'Replay histórico.' })
  @Post('materials/:materialId/reports')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Reportar un material publicado; no modifica su publicación' })
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiBody({
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['reason'],
      properties: {
        reason: { type: 'string', enum: [...reasons] },
        details: { type: 'string', nullable: true, maxLength: 2000 },
      },
      description: 'OTHER requiere detalles no vacíos.',
    },
  })
  async create(
    @Req() req: ReportRequest,
    @Param('materialId') id: string,
    @Headers('idempotency-key') key: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ) {
    const result = await this.reports.create(req.actor, uuid(id), uuid(key), createInput(body));
    res.status(result.replay ? 200 : 201);
    return result.body;
  }
  @ApiResponse({ status: 200, schema: ReportPageDto, description: 'Página de reportes.' })
  @ApiQuery({ name: 'page', required: false, schema: { type: 'integer', minimum: 1, default: 1 } })
  @ApiQuery({
    name: 'pageSize',
    required: false,
    schema: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
  })
  @Get('reports/me')
  @Header('Cache-Control', 'no-store')
  mine(@Req() req: ReportRequest, @Query() query: Record<string, unknown>) {
    return this.reports.list(req.actor, pageInput(query), false);
  }
  @ApiResponse({ status: 200, schema: ReportDto, description: 'Reporte accesible.' })
  @Get('reports/:reportId')
  @Header('Cache-Control', 'no-store')
  get(@Req() req: ReportRequest, @Param('reportId') id: string) {
    return this.reports.get(req.actor, uuid(id));
  }
  @ApiResponse({ status: 200, schema: ReportPageDto, description: 'Página de reportes.' })
  @ApiQuery({ name: 'page', required: false, schema: { type: 'integer', minimum: 1, default: 1 } })
  @ApiQuery({
    name: 'pageSize',
    required: false,
    schema: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
  })
  @ApiQuery({
    name: 'status',
    required: false,
    enum: ['OPEN', 'IN_REVIEW', 'RESOLVED', 'DISMISSED'],
  })
  @Get('moderation/reports')
  @SetMetadata('reportAdmin', true)
  @Header('Cache-Control', 'no-store')
  pending(@Req() req: ReportRequest, @Query() query: Record<string, unknown>) {
    return this.reports.list(req.actor, pageInput(query, true), true);
  }
  @ApiResponse({
    status: 200,
    schema: ReportDto,
    description: 'Reporte tratado o replay histórico.',
  })
  @Patch('moderation/reports/:reportId')
  @SetMetadata('reportAdmin', true)
  @Header('Cache-Control', 'no-store')
  @ApiHeader({ name: 'Idempotency-Key', required: true })
  @ApiBody({
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['status', 'expectedUpdatedAt'],
      properties: {
        status: { type: 'string', enum: ['IN_REVIEW', 'RESOLVED', 'DISMISSED'] },
        expectedUpdatedAt: { type: 'string', format: 'date-time' },
        resolutionNote: { type: 'string', maxLength: 2000 },
      },
      description: 'RESOLVED/DISMISSED requieren nota. No retira el material.',
    },
  })
  async update(
    @Req() req: ReportRequest,
    @Param('reportId') id: string,
    @Headers('idempotency-key') key: string,
    @Body() body: unknown,
  ) {
    return (await this.reports.update(req.actor, uuid(id), uuid(key), updateInput(body))).body;
  }
}
