import {
  Controller,
  Delete,
  Get,
  Put,
  Header,
  HttpCode,
  Param,
  Query,
  Req,
  Res,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiResponse, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { FavoriteService } from './favorite.service';
import { FavoriteGuard, type FavoriteRequest } from './favorite.guard';
import { FavoriteErrorFilter } from './favorite-error.filter';
import { FavoriteDto, FavoritePageDto, ErrorDto } from './favorite-openapi';
import { materialId, pageInput, noPayload } from './favorite-contract';
@ApiTags('Quality favorites')
@ApiBearerAuth()
@ApiResponse({ status: 400, schema: ErrorDto, description: 'UUID, cuerpo o consulta inválidos.' })
@ApiResponse({
  status: 401,
  schema: ErrorDto,
  description: 'Identidad ausente, inválida o revocada; WWW-Authenticate: Bearer.',
})
@ApiResponse({ status: 403, schema: ErrorDto, description: 'Cuenta inactiva.' })
@ApiResponse({ status: 502, schema: ErrorDto, description: 'Respuesta de dependencia inválida.' })
@ApiResponse({ status: 503, schema: ErrorDto, description: 'Dependencia no disponible.' })
@UseGuards(FavoriteGuard)
@UseFilters(FavoriteErrorFilter)
@Controller('quality')
export class FavoriteController {
  constructor(private readonly favorites: FavoriteService) {}
  @Put('materials/:materialId/favorite')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary: 'Guardar material publicado en favoritos propios',
    description:
      'Sin cuerpo. Repetir conserva id y createdAt; verifica visibilidad en cada solicitud. Se permite material propio.',
  })
  @ApiResponse({ status: 201, schema: FavoriteDto, description: 'Favorito creado.' })
  @ApiResponse({ status: 200, schema: FavoriteDto, description: 'Favorito ya existente.' })
  @ApiResponse({ status: 404, schema: ErrorDto, description: 'Material oculto o inexistente.' })
  async put(
    @Req() req: FavoriteRequest,
    @Param('materialId') id: string,
    @Res({ passthrough: true }) res: Response,
  ) {
    noPayload(req.body, req.query, req.headers['content-length'], req.headers['transfer-encoding']);
    const result = await this.favorites.put(req.actor.id, materialId(id));
    res.status(result.created ? 201 : 200);
    return result.body;
  }
  @Delete('materials/:materialId/favorite')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary: 'Eliminar favorito propio',
    description: 'Sin cuerpo. Devuelve 204 aunque no exista. No consulta Material.',
  })
  @ApiResponse({ status: 204, description: 'Relación propia eliminada o ausente.' })
  async remove(@Req() req: FavoriteRequest, @Param('materialId') id: string) {
    noPayload(req.body, req.query, req.headers['content-length'], req.headers['transfer-encoding']);
    await this.favorites.remove(req.actor.id, materialId(id));
  }
  @Get('favorites/me')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({
    summary: 'Listar favoritos propios',
    description:
      'Orden createdAt DESC,id DESC. Incluye referencias no disponibles sin metadatos privados; errores de dependencia no se convierten en available=false.',
  })
  @ApiQuery({
    name: 'page',
    required: false,
    schema: { type: 'integer', minimum: 1, maximum: 2147483647, default: 1 },
  })
  @ApiQuery({
    name: 'pageSize',
    required: false,
    schema: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
  })
  @ApiResponse({
    status: 200,
    schema: FavoritePageDto,
    description: 'Página de relaciones propias.',
  })
  list(@Req() req: FavoriteRequest, @Query() query: Record<string, unknown>) {
    const { page, pageSize } = pageInput(query);
    return this.favorites.list(req.actor.id, page, pageSize);
  }
}
