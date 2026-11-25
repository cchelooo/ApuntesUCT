import {
  Controller,
  Get,
  Header,
  Param,
  ParseUUIDPipe,
  Query,
  Req,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiBearerAuth,
  ApiForbiddenResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiServiceUnavailableResponse,
  ApiTags,
  ApiUnauthorizedResponse,
} from '@nestjs/swagger';
import { MaterialsService, DownloadResult } from '../../application/services/materials.service';
import {
  MaterialModeratorGuard,
  type ModerationRequest,
} from '../../infrastructure/auth/material-moderator.guard';
import { DownloadMaterialQueryDto } from './dto/download-material-query.dto';
import { buildContentDisposition } from './content-disposition';

@ApiTags('materials')
@ApiOkResponse({
  content: { 'application/pdf': { schema: { type: 'string', format: 'binary' } } },
  description: 'PDF con Content-Disposition: inline.',
})
@ApiBadRequestResponse({ description: 'UUID o query inválidos.' })
@ApiNotFoundResponse({
  description: 'Material, versión o PDF no disponible en el estado permitido.',
})
@ApiServiceUnavailableResponse({ description: 'Almacenamiento no disponible.' })
@Controller('materials')
export class MaterialPreviewController {
  constructor(private readonly materials: MaterialsService) {}

  @Get(':id/preview')
  @Header('Cache-Control', 'no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({
    summary: 'Previsualizar un PDF publicado',
    description: 'Versión actual o versionId. No expone URLs ni claves de almacenamiento.',
  })
  async preview(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Query() query: DownloadMaterialQueryDto,
  ): Promise<StreamableFile> {
    return this.file(await this.materials.preview(id, query.versionId));
  }

  @Get('admin/:id/preview')
  @UseGuards(MaterialModeratorGuard)
  @ApiBearerAuth()
  @ApiUnauthorizedResponse({ description: 'JWT ausente o inválido.' })
  @ApiForbiddenResponse({ description: 'Requiere MODERATOR o ADMIN.' })
  @ApiOperation({ summary: 'Previsualizar un PDF pendiente de revisión con auditoría' })
  @Header('Cache-Control', 'no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  async previewPending(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Query() query: DownloadMaterialQueryDto,
    @Req() request: ModerationRequest,
  ): Promise<StreamableFile> {
    return this.file(await this.materials.previewPending(id, request.identity, query.versionId));
  }

  private file(result: DownloadResult): StreamableFile {
    return new StreamableFile(result.stream, {
      type: 'application/pdf',
      disposition: buildContentDisposition(result.filename, 'inline'),
      length: result.size,
    });
  }
}
