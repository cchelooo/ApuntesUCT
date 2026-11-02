import {
  Controller,
  Param,
  ParseUUIDPipe,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CreateMaterialVersion } from '../../application/use-cases/create-material-version';
import { MaterialAuthorProvider } from '../../infrastructure/auth/material-author.provider';
import { MAX_FILE_SIZE_BYTES, materialUploadPipe } from '../validators/material-upload.pipe';

@ApiTags('Materials')
@ApiBearerAuth()
@Controller('materials/:id/versions')
export class MaterialVersionController {
  constructor(
    private readonly create: CreateMaterialVersion,
    private readonly author: MaterialAuthorProvider,
  ) {}

  @Post()
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: MAX_FILE_SIZE_BYTES + 1, files: 1 } }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Crear una nueva versión de archivo conservando las anteriores' })
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @ApiResponse({ status: 201, description: 'Nueva versión registrada con numeración incremental.' })
  @ApiResponse({
    status: 400,
    description: 'UUID inválido, archivo ausente o vacío, o material LINK.',
  })
  @ApiResponse({ status: 401, description: 'Contexto de autor no disponible.' })
  @ApiResponse({ status: 403, description: 'El usuario no es el autor del material.' })
  @ApiResponse({ status: 404, description: 'Material no encontrado.' })
  @ApiResponse({ status: 413, description: 'Archivo mayor que 15 MiB.' })
  @ApiResponse({ status: 415, description: 'Formato no soportado.' })
  @ApiResponse({ status: 502, description: 'No se pudo almacenar el archivo.' })
  createVersion(
    @Param('id', new ParseUUIDPipe()) id: string,
    @UploadedFile(materialUploadPipe(true)) file: Express.Multer.File,
  ) {
    return this.create.execute(id, this.author.resolve(), file);
  }
}
