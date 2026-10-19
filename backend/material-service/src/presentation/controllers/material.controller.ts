import {
  Controller,
  Post,
  Body,
  UploadedFile,
  UseInterceptors,
  Req,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiTags,
  ApiConsumes,
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiBody,
  ApiExtraModels,
} from '@nestjs/swagger';
import type { Request } from 'express';
import {
  CreateMaterialDto,
  MaterialType,
  MATERIAL_MIME_TYPES,
  MATERIAL_TYPE_DESCRIPTION,
} from '../dto/create-material.dto';
import { ErrorResponseDto } from '../dto/error-response.dto';
import { CreateMaterialResponseDto } from '../dto/material-response.dto';
import { CreateMaterial } from '../../application/use-cases/create-material';
import { MaterialAuthorProvider } from '../../infrastructure/auth/material-author.provider';
import { MAX_FILE_SIZE_BYTES, materialUploadPipe } from '../validators/material-upload.pipe';

@ApiTags('Materials')
@Controller('materials')
@ApiBearerAuth()
@ApiExtraModels(ErrorResponseDto, CreateMaterialResponseDto)
export class MaterialController {
  constructor(
    private readonly create: CreateMaterial,
    private readonly author: MaterialAuthorProvider,
  ) {}

  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_FILE_SIZE_BYTES + 1, files: 1 },
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Subir y registrar un nuevo material o enlace académico con validaciones de seguridad',
    description: `
**REGLAS DE SEGURIDAD Y VALIDACIÓN EN SERVIDOR:**
- **Contexto de autor:** Requiere un contexto válido resuelto por MaterialAuthorProvider (retorna \`401\` si no está disponible o habilitado). El contexto local temporal está limitado a development según la configuración del servicio.
- **Tamaño máximo:** 15 MB del contrato equivalen a 15.728.640 bytes (15 MiB). Retorna \`413\` si se excede.
- **Tipos MIME permitidos:** ${MATERIAL_MIME_TYPES.join(', ')} (retorna \`415\` si no es compatible).
- **Archivo vacío:** Se rechaza si el archivo pesa 0 bytes (retorna \`400\`).
- **Metadatos obligatorios:** \`title\`, \`year\` (YYYY), \`type\` y \`subjectId\` (retorna \`400\` si fallan).
- **Referencias de Catalog:** \`subjectId\` debe ser un UUID de una asignatura activa con carrera y universidad activas. Si se envían \`careerId\` o \`professorId\`, deben existir, estar activos y ser compatibles con la asignatura. La universidad del contexto de autor también debe ser compatible cuando esté configurada. Referencias inválidas retornan \`400\` con \`field\`; Catalog no disponible retorna \`502\`.
- **Ejemplos académicos:** Los UUID del formulario son ilustrativos; reemplazarlos por referencias existentes en Catalog.
- **Reglas por tipo:** \`LINK\` exige \`externalLink\` válido y prohíbe archivo. \`DOCUMENT\`, \`PRESENTATION\`, \`EXAM\` y \`SUMMARY\` exigen archivo local.
- **Relación del tipo:** ${MATERIAL_TYPE_DESCRIPTION}
- **Endpoint relacionado:** GET /materials lista materiales publicados con materialTypeId.
- **Almacenamiento:** Las validaciones previas, incluidas las referencias de Catalog, se ejecutan antes de almacenar el archivo y persistir el material.
    `,
  })
  @ApiBody({
    type: CreateMaterialDto,
    description:
      'Metadatos y archivo mediante multipart/form-data. ' +
      'Las referencias académicas deben ser UUID existentes y compatibles en Catalog. ' +
      'careerId y professorId son opcionales: omitirlos si no se utilizan. ' +
      'Los UUID de ejemplo son ilustrativos y deben reemplazarse por referencias reales.',
  })
  @ApiResponse({
    status: 201,
    description: 'Material persistido en estado PENDING_REVIEW.',
    type: CreateMaterialResponseDto,
  })
  @ApiResponse({
    status: 400,
    description:
      'Metadatos incorrectos, año inválido, archivo vacío, regla de tipo incumplida o referencia ' +
      'académica inválida. Los errores de referencias de Catalog incluyen field.',
  })
  @ApiResponse({ status: 401, description: 'Contexto de autor ausente, inválido o no habilitado.' })
  @ApiResponse({ status: 413, description: 'El archivo supera los 15.728.640 bytes permitidos.' })
  @ApiResponse({ status: 415, description: 'Formato de archivo no soportado.' })
  @ApiResponse({ status: 500, description: 'Error inesperado en el servidor.' })
  @ApiResponse({
    status: 502,
    description: 'Catalog no disponible para validar referencias o fallo al almacenar el archivo.',
  })
  async createMaterial(
    @Req() req: Request,
    @Body() dto: CreateMaterialDto,
    @UploadedFile(materialUploadPipe())
    file?: Express.Multer.File,
  ) {
    // Validación adicional de archivo vacío.
    if (file && file.size === 0) {
      throw new BadRequestException(
        'El archivo adjunto está vacío (0 bytes) y no puede ser procesado.',
      );
    }

    // Reglas cruzadas por tipo de material.
    if (dto.type === MaterialType.LINK) {
      if (!dto.externalLink) {
        throw new BadRequestException(
          'Para materiales de tipo LINK es obligatorio especificar externalLink (URL válida).',
        );
      }
      if (file) {
        throw new BadRequestException(
          'Los materiales de tipo LINK no deben incluir un archivo adjunto.',
        );
      }
    } else if (!file) {
      throw new BadRequestException(
        `Para el tipo de material '${dto.type}' es obligatorio adjuntar un archivo local.`,
      );
    }

    return this.create.execute(dto, this.author.resolve(), file);
  }
}
