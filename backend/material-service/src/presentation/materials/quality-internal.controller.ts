import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Put,
  Query,
  Req,
  StreamableFile,
  UseGuards,
  HttpException,
} from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { MaterialsService } from '../../application/services/materials.service';
import { QualityModerationService } from '../../application/services/quality-moderation.service';
import {
  QualityServiceGuard,
  type InternalRequest,
} from '../../infrastructure/moderation/quality-service.guard';
import { decision, pageQuery } from '../../infrastructure/moderation/decision';
import type { AuditRequest } from '../../infrastructure/moderation/access-audit';
import { buildContentDisposition } from './content-disposition';
@ApiExcludeController()
@Controller('internal/v1/quality')
@UseGuards(QualityServiceGuard)
export class QualityInternalController {
  constructor(
    private readonly moderation: QualityModerationService,
    private readonly materials: MaterialsService,
  ) {}
  @Get('materials') async list(@Query() query: Record<string, unknown>, @Req() req: AuditRequest) {
    const p = await this.moderation.list(pageQuery(query));
    req.auditCount = p.items.length;
    return p;
  }
  @Get('materials/:materialId') async read(
    @Param('materialId', ParseUUIDPipe) id: string,
    @Req() req: AuditRequest,
  ) {
    const m = await this.moderation.read(id);
    req.auditRevision = m.revision;
    return m;
  }
  @Get('materials/:materialId/versions/:versionId/download')
  async download(
    @Param('materialId', ParseUUIDPipe) id: string,
    @Param('versionId', ParseUUIDPipe) version: string,
    @Req() req: AuditRequest,
  ) {
    const file = await this.materials.downloadForReview(id, version);
    req.downloadAuthorized = true;
    return new StreamableFile(file.stream, {
      type: file.mimeType,
      length: file.size,
      disposition: buildContentDisposition(file.filename, 'attachment'),
    });
  }
  @Put('materials/:materialId/decisions/:operationId') async apply(
    @Param('materialId', ParseUUIDPipe) id: string,
    @Param('operationId', ParseUUIDPipe) operation: string,
    @Body() body: unknown,
    @Req() req: InternalRequest,
  ) {
    const outcome = await this.moderation.apply(id, operation, decision(body), req.serviceContext);
    if (outcome.status !== 200) throw new HttpException(outcome.body as object, outcome.status);
    return outcome.body;
  }
  @Get('decisions/:operationId') receipt(
    @Param('operationId', ParseUUIDPipe) id: string,
    @Req() req: InternalRequest,
  ) {
    return this.moderation.receipt(id, req.serviceContext);
  }
}
