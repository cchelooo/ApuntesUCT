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
import { ListMaterialsQueryDto } from '../../application/dtos/list-materials-query.dto';
import {
  PendingMaterialDetailDto,
  PendingMaterialPageDto,
} from '../../application/dtos/pending-material.dto';
import { MaterialsService } from '../../application/services/materials.service';
import {
  MaterialModeratorGuard,
  type ModerationRequest,
} from '../../infrastructure/auth/material-moderator.guard';
import { ErrorResponseDto } from '../dto/error-response.dto';
import { DownloadMaterialQueryDto } from './dto/download-material-query.dto';
import { buildContentDisposition } from './content-disposition';

/**
 * Endpoints administrativos separados de los públicos (#460).
 * Requieren JWT firmado con rol MODERATOR o ADMIN; nunca sirven materiales
 * PUBLICADOS ni exponen claves/URLs de MinIO.
 */
@ApiTags('materials')
@Controller('materials/admin')
@UseGuards(MaterialModeratorGuard)
@ApiBearerAuth()
export class MaterialAdminController {
  constructor(private readonly materials: MaterialsService) {}

  @Get('pending')
  @Header('Cache-Control', 'no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({
    summary: 'Listar materiales pendientes de revisión con paginación',
    description:
      'Solo MODERATOR/ADMIN. Orden createdAt DESC, id DESC. No incluye claves de almacenamiento.',
  })
  @ApiOkResponse({ type: PendingMaterialPageDto })
  @ApiBadRequestResponse({ type: ErrorResponseDto, description: 'Paginación inválida.' })
  @ApiUnauthorizedResponse({ type: ErrorResponseDto, description: 'JWT ausente o inválido.' })
  @ApiForbiddenResponse({ type: ErrorResponseDto, description: 'Requiere MODERATOR o ADMIN.' })
  listPending(
    @Query() query: ListMaterialsQueryDto,
    @Req() request: ModerationRequest,
  ): Promise<PendingMaterialPageDto> {
    return this.materials.listPending(query, request.identity);
  }

  @Get('pending/:id')
  @Header('Cache-Control', 'no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({
    summary: 'Obtener el detalle privado de un material pendiente',
    description:
      'Incluye el historial de versiones y externalLink. Nunca expone storageKey ni credenciales.',
  })
  @ApiOkResponse({ type: PendingMaterialDetailDto })
  @ApiBadRequestResponse({ type: ErrorResponseDto, description: 'UUID inválido.' })
  @ApiUnauthorizedResponse({ type: ErrorResponseDto, description: 'JWT ausente o inválido.' })
  @ApiForbiddenResponse({ type: ErrorResponseDto, description: 'Requiere MODERATOR o ADMIN.' })
  @ApiNotFoundResponse({
    type: ErrorResponseDto,
    description: 'Material inexistente o que no está PENDING_REVIEW.',
  })
  detailPending(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Req() request: ModerationRequest,
  ): Promise<PendingMaterialDetailDto> {
    return this.materials.detailPending(id, request.identity);
  }

  @Get('pending/:id/download')
  @Header('Cache-Control', 'no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({
    summary: 'Descargar el archivo de un material pendiente para revisión',
    description:
      'Versión actual o la indicada en versionId. Stream con MIME real y Content-Disposition: attachment.',
  })
  @ApiOkResponse({
    content: { 'application/octet-stream': { schema: { type: 'string', format: 'binary' } } },
    description: 'Archivo privado del material pendiente.',
  })
  @ApiBadRequestResponse({ type: ErrorResponseDto, description: 'UUID o query inválidos.' })
  @ApiUnauthorizedResponse({ type: ErrorResponseDto, description: 'JWT ausente o inválido.' })
  @ApiForbiddenResponse({ type: ErrorResponseDto, description: 'Requiere MODERATOR o ADMIN.' })
  @ApiNotFoundResponse({
    type: ErrorResponseDto,
    description: 'Material/versión inexistente o que no está PENDING_REVIEW.',
  })
  @ApiServiceUnavailableResponse({
    type: ErrorResponseDto,
    description: 'Almacenamiento no disponible.',
  })
  async downloadPending(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Query() query: DownloadMaterialQueryDto,
    @Req() request: ModerationRequest,
  ): Promise<StreamableFile> {
    const result = await this.materials.downloadPending(id, request.identity, query.versionId);
    return new StreamableFile(result.stream, {
      type: result.mimeType,
      disposition: buildContentDisposition(result.filename),
      length: result.size,
    });
  }
}
