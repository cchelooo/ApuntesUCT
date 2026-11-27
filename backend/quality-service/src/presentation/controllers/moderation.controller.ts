import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  Res,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiBody, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { ModerationService } from '../../application/moderation.service';
import { MaterialClient } from '../../infrastructure/moderation/material-client';
import { QualityUserGuard, UserRequest } from '../../infrastructure/moderation/quality-user.guard';
import { AuditRequest } from '../../infrastructure/moderation/access-audit';
import { decision, pageQuery } from '../../infrastructure/moderation/decision';
import { fault, uuid } from '../../infrastructure/moderation/service-assertion';
@ApiTags('Moderación')
@ApiBearerAuth()
@UseGuards(QualityUserGuard)
@ApiResponse({ status: 401, description: 'Identidad ausente, inválida o revocada.' })
@ApiResponse({ status: 403, description: 'Permiso insuficiente o autorrevisión.' })
@Controller('quality/moderation')
export class ModerationController {
  constructor(
    private readonly moderation: ModerationService,
    private readonly material: MaterialClient,
  ) {}
  @Get('materials') async list(
    @Query() query: Record<string, unknown>,
    @Req() req: UserRequest & AuditRequest,
  ) {
    const p = await this.material.list(pageQuery(query), req.identity, req.requestId);
    req.auditCount = p.items.length;
    return p;
  }
  @Get('materials/:materialId') async read(
    @Param('materialId', ParseUUIDPipe) id: string,
    @Req() req: UserRequest & AuditRequest,
  ) {
    const m = await this.material.read(id, req.identity, req.requestId);
    req.auditRevision = m.revision;
    return m;
  }
  @Get('materials/:materialId/versions/:versionId/download') async download(
    @Param('materialId', ParseUUIDPipe) id: string,
    @Param('versionId', ParseUUIDPipe) version: string,
    @Req() req: UserRequest & AuditRequest,
  ) {
    const f = await this.material.download(id, version, req.identity, req.requestId);
    req.downloadAuthorized = true;
    req.res?.once('close', () => f.stream.destroy());
    return new StreamableFile(f.stream, {
      type: f.mime,
      length: f.length,
      disposition: f.disposition,
    });
  }
  @Post('materials/:materialId/decisions')
  @ApiBody({
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['action', 'expectedRevision'],
      properties: {
        action: { type: 'string', enum: ['APPROVE', 'REJECT'] },
        expectedRevision: { type: 'integer', minimum: 1, maximum: 2147483647 },
        reason: { type: 'string', minLength: 1, maxLength: 2000 },
      },
      description: 'REJECT exige reason no vacío.',
    },
  })
  @ApiResponse({
    status: 202,
    description: 'Operación duraderamente aceptada, pendiente de aplicación.',
  })
  @ApiResponse({ status: 200, description: 'Replay de operación terminal.' })
  @ApiResponse({ status: 409, description: 'Conflicto de revisión, transición o idempotencia.' })
  async accept(
    @Param('materialId', ParseUUIDPipe) id: string,
    @Headers('idempotency-key') key: string,
    @Body() raw: unknown,
    @Req() req: UserRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    if (!uuid(key)) throw fault(400, 'VALIDATION_ERROR', 'Idempotency-Key debe ser UUID.');
    const result = await this.moderation.accept(
      id.toLowerCase(),
      key.toLowerCase(),
      decision(raw),
      req.identity,
      req.requestId,
    );
    res.status(result.status);
    res.setHeader('Location', '/api/v1/quality/moderation/operations/' + result.operation.id);
    return result.operation;
  }
  @Get('operations/:operationId') get(@Param('operationId', ParseUUIDPipe) id: string) {
    return this.moderation.get(id);
  }
}
