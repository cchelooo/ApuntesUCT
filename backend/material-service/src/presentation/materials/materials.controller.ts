import { Controller, Get, Query } from '@nestjs/common';
import { ApiBadRequestResponse, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ListMaterialsQueryDto } from '../../application/dtos/list-materials-query.dto';
import { MaterialPageDto } from '../../application/dtos/material-page.dto';
import { MaterialsService } from '../../application/services/materials.service';

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
}
