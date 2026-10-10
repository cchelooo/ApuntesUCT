import { Controller, Get, Param, ParseUUIDPipe, Query, StreamableFile } from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiProduces,
  ApiTags,
} from '@nestjs/swagger';
import { ListMaterialsQueryDto } from '../../application/dtos/list-materials-query.dto';
import { MaterialPageDto } from '../../application/dtos/material-page.dto';
import { MaterialsService } from '../../application/services/materials.service';
import { DownloadMaterialQueryDto } from './dto/download-material-query.dto';

function sanitizeFilename(filename: string): string {
  const fallback = 'material';
  if (!filename) return fallback;
  const safe = filename.replace(/[\r\n"]+/g, '_').replace(/[^\x20-\x7e]/g, '_').trim();
  return safe || fallback;
}

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
  @ApiBadRequestResponse({ description: 'Paginación inválida o parámetros desconocidos.' })
  list(
    @Query()
    query: ListMaterialsQueryDto,
  ): Promise<MaterialPageDto> {
    return this.materials.list(query);
  }

  @Get(':id/download')
  @ApiOperation({
    summary: 'Descargar la última versión publicada de un material',
    description:
      'Resuelve internamente la versión (la de mayor versionNumber, o la indicada en versionId) y streama el archivo desde MinIO. La clave de almacenamiento nunca se expone.',
  })
  @ApiProduces('application/octet-stream')
  @ApiOkResponse({
    description:
      'Stream del archivo con Content-Type, Content-Length y Content-Disposition: attachment; filename=...',
  })
  @ApiBadRequestResponse({ description: 'UUID inválido o parámetro desconocido.' })
  @ApiNotFoundResponse({ description: 'Material, versión o archivo inexistente.' })
  async download(
    @Param('id', new ParseUUIDPipe()) id: string,
    @Query() query: DownloadMaterialQueryDto,
  ): Promise<StreamableFile> {
    const result = await this.materials.download(id, query.versionId);
    return new StreamableFile(result.stream, {
      type: result.mimeType,
      disposition: `attachment; filename="${sanitizeFilename(result.filename)}"`,
      length: result.size,
    });
  }
}
