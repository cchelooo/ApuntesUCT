import { Controller, Get, Param, ParseUUIDPipe, Query, StreamableFile } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiServiceUnavailableResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { ListMaterialsQueryDto } from '../../application/dtos/list-materials-query.dto';
import { MaterialPageDto } from '../../application/dtos/material-page.dto';
import { MaterialDetailDto } from '../../application/dtos/material-detail.dto';
import { MaterialsService } from '../../application/services/materials.service';
import { DownloadMaterialQueryDto } from './dto/download-material-query.dto';
import { ErrorResponseDto } from '../dto/error-response.dto';
import { buildContentDisposition } from './content-disposition';

@ApiTags('materials')
@Controller('materials')
export class MaterialsController {
  constructor(private readonly materials: MaterialsService) {}

  @Get()
  @ApiOperation({
    summary: 'Listar materiales publicados con paginación',
    description:
      'Orden: createdAt DESC, id DESC. Solo acepta page y pageSize; no realiza búsqueda textual. El desplazamiento máximo es 2147483647.',
  })
  @ApiOkResponse({ type: MaterialPageDto })
  @ApiBadRequestResponse({
    type: ErrorResponseDto,
    description: 'Paginación inválida o parámetros desconocidos.',
  })
  list(@Query() query: ListMaterialsQueryDto): Promise<MaterialPageDto> {
    return this.materials.list(query);
  }

  @Get(':id/download')
  @ApiOperation({
    summary: 'Descargar la versión actual o una versión específica de un material',
    description:
      'Resuelve internamente la versión (la de mayor versionNumber, o la indicada en versionId) y streama el archivo desde MinIO. La clave de almacenamiento nunca se expone.',
  })
  @ApiServiceUnavailableResponse({
    type: ErrorResponseDto,
    description: 'Almacenamiento no disponible.',
  })
  @ApiOkResponse({
    content: { 'application/octet-stream': { schema: { type: 'string', format: 'binary' } } },
    description:
      'Stream del archivo con Content-Type, Content-Length y Content-Disposition: attachment; filename="<ASCII>"; filename*=UTF-8\'\'<nombre original>.',
  })
  @ApiBadRequestResponse({
    type: ErrorResponseDto,
    description: 'UUID inválido o parámetro desconocido.',
  })
  @ApiNotFoundResponse({
    type: ErrorResponseDto,
    description: 'Material, versión o archivo inexistente.',
  })
  async download(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Query() query: DownloadMaterialQueryDto,
  ): Promise<StreamableFile> {
    const result = await this.materials.download(id, query.versionId);
    return new StreamableFile(result.stream, {
      type: result.mimeType,
      disposition: buildContentDisposition(result.filename),
      length: result.size,
    });
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Obtener detalle de un material publicado y su historial de versiones',
    description:
      'Solo materiales PUBLISHED. versions contiene el historial completo por versionNumber descendente. currentVersion corresponde a su primer elemento; para enlaces sin archivo devuelve null y versions vacío. fileSize es una cadena decimal de bytes. No expone claves ni rutas de almacenamiento.',
  })
  @ApiOkResponse({ type: MaterialDetailDto })
  @ApiBadRequestResponse({
    type: ErrorResponseDto,
    description: 'El identificador no es un UUID válido.',
  })
  @ApiNotFoundResponse({
    type: ErrorResponseDto,
    description: 'Material inexistente/no publicado o documento sin versión disponible.',
  })
  detail(@Param('id', new ParseUUIDPipe()) id: string): Promise<MaterialDetailDto> {
    return this.materials.detail(id);
  }
}
