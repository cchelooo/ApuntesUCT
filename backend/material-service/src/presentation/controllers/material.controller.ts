import { 
  Controller, Post, Body, UploadedFile, UseInterceptors, Req,
  ParseFilePipe, MaxFileSizeValidator, FileValidator,
  PayloadTooLargeException, UnsupportedMediaTypeException, BadRequestException 
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { 
  ApiTags, ApiConsumes, ApiBearerAuth, ApiOperation, 
  ApiResponse, ApiBody, ApiExtraModels 
} from '@nestjs/swagger';
import type { Request } from 'express';
import { CreateMaterialDto, MaterialType } from '../dto/create-material.dto';
import { ErrorResponseDto } from '../dto/error-response.dto';
import { CreateMaterialResponseDto } from '../dto/material-response.dto';

import { CreateMaterial } from '../../application/use-cases/create-material';
import { MaterialAuthorProvider } from '../../infrastructure/auth/material-author.provider';
import { MaterialFileTypeValidator } from '../validators/material-file-type.validator';

const MATERIAL_MIME_TYPES = [
  'application/pdf',
  'application/msword', // DOC
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // DOCX
  'application/vnd.ms-powerpoint', // PPT
  'application/vnd.openxmlformats-officedocument.presentationml.presentation', // PPTX
];

const MATERIAL_TYPE_DESCRIPTION = 'MaterialType.name define la categoría del material relacionado con materialTypeId y los recursos activos mostrados en GET /materials.';

const MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024; // 15 MB exactos (15,728,640 bytes)

/**
 * Validador personalizado para detectar archivos vacíos (0 bytes) antes del filtro MIME
 */
class EmptyFileValidator extends FileValidator<object> {
  public isValid(file?: Express.Multer.File): boolean {
    if (!file) return true;
    return file.size > 0;
  }

  public buildErrorMessage(): string {
    return 'El archivo adjunto está vacío (0 bytes) y no puede ser procesado.';
  }
}

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
- **Autenticación:** Requiere cabecera \`Authorization: Bearer <token>\` (Retorna \`401\` si falta o es inválida).
- **Tamaño máximo:** Límite estricto de 15 MB / 15,728,640 bytes (Retorna \`413\` si se excede).
- **Tipos MIME permitidos:** ${MATERIAL_MIME_TYPES.join(', ')} (Retorna \`415\` si no es compatible).
- **Archivo vacío:** Se rechaza si el archivo pesa 0 bytes (Retorna \`400\`).
- **Metadatos obligatorios y formato:** \`title\`, \`year\` (YYYY), \`type\` y \`subjectId\` validados rigurosamente (Retorna \`400\` si fallan).
- **Reglas de Negocio por Tipo:** 
  - \`LINK\` exige \`externalLink\` válido y prohíbe archivo.
  - \`DOCUMENT\`, \`PRESENTATION\`, \`EXAM\`, \`SUMMARY\` exigen archivo local obligatorio.
- **Relación del tipo:** ${MATERIAL_TYPE_DESCRIPTION}
- **Endpoints relacionados:** GET /materials para listar recursos activos con materialTypeId.
- **Seguridad de almacenamiento:** Ningún archivo es almacenado ni procesado si la petición falla en las validaciones previas.
    `
  })
  @ApiBody({
    description: 'Metadatos y archivo adjunto',
    schema: {
      type: 'object',
      properties: {
        title: { type: 'string', example: 'Guía Práctica de Álgebra Lineal' },
        description: { type: 'string', example: 'Ejercicios resueltos sobre valores y vectores propios.' },
        year: { type: 'string', example: '2026' },
        type: { 
          type: 'string', 
          enum: Object.values(MaterialType), 
          example: MaterialType.DOCUMENT,
          description: MATERIAL_TYPE_DESCRIPTION 
        },
        subjectId: { type: 'string', example: 'SUBJ-102' },
        careerId: { type: 'string', example: 'CAREER-INF-01' },
        professorId: { type: 'string', example: 'prof_88321' },
        externalLink: { type: 'string', example: 'https://drive.google.com/file/d/xyz/view' },
        file: { 
          type: 'string', 
          format: 'binary', 
          description: `Archivo binario local (Máx 15MB). MIMEs permitidos: ${MATERIAL_MIME_TYPES.join(', ')}` 
        },
      },
      required: ['title', 'year', 'type', 'subjectId'],
    },
  })
  @ApiResponse({ status: 201, description: 'Material persistido en estado PENDING_REVIEW.', type: CreateMaterialResponseDto })
  @ApiResponse({ status: 400, description: 'Bad Request - Metadatos incorrectos, año inválido, archivo vacío o regla de tipo incumplida.' })
  @ApiResponse({ status: 401, description: 'Unauthorized - Petición sin token de autenticación.' })
  @ApiResponse({ status: 404, description: 'Not Found - Asignatura o recurso no encontrado.' })
  @ApiResponse({ status: 413, description: 'Payload Too Large - El archivo supera los 15 MB.' })
  @ApiResponse({ status: 415, description: 'Unsupported Media Type - Formato de archivo no soportado.' })
  @ApiResponse({ status: 500, description: 'Internal Server Error - Error inesperado en el servidor.' })
  @ApiResponse({ status: 502, description: 'Bad Gateway - Error de comunicación con servicios dependientes.' })
  async createMaterial(
    @Req() req: Request,
    @Body() dto: CreateMaterialDto,
    @UploadedFile(
      new ParseFilePipe({
        fileIsRequired: false,
        validators: [
          new EmptyFileValidator({}),
          new MaxFileSizeValidator({ maxSize: MAX_FILE_SIZE_BYTES + 1 }),
          new MaterialFileTypeValidator(),
        ],
        exceptionFactory: (error) => {
          if (error.includes('vacío') || error.includes('empty')) {
            return new BadRequestException('El archivo adjunto está vacío (0 bytes) y no puede ser procesado.');
          }
          if (error.includes('expected size') || error.includes('file size')) {
            return new PayloadTooLargeException(`El archivo excede el tamaño máximo permitido de 15 MB (${MAX_FILE_SIZE_BYTES} bytes).`);
          }
          if (error.includes('expected type') || error.includes('file type') || error.includes('Tipo de archivo')) {
            return new UnsupportedMediaTypeException('Tipo de archivo no admitido. Formatos válidos: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).');
          }
          return new BadRequestException(error);
        },
      })
    ) file?: Express.Multer.File,
  ) {
    // 1. Validación de Archivo Vacío (0 bytes) por seguridad adicional
    if (file && file.size === 0) {
      throw new BadRequestException('El archivo adjunto está vacío (0 bytes) y no puede ser procesado.');
    }

    // 2. Reglas de Negocio y Validación Cruzada por Tipo de Material (400)
    if (dto.type === MaterialType.LINK) {
      if (!dto.externalLink) {
        throw new BadRequestException('Para materiales de tipo LINK es obligatorio especificar externalLink (URL válida).');
      }
      if (file) {
        throw new BadRequestException('Los materiales de tipo LINK no deben incluir un archivo adjunto.');
      }
    } else {
      // DOCUMENT, PRESENTATION, EXAM, SUMMARY exigen archivo obligatorio
      if (!file) {
        throw new BadRequestException(`Para el tipo de material '${dto.type}' es obligatorio adjuntar un archivo local.`);
      }
    }

    // 3. Ejecución protegida del caso de uso
    return this.create.execute(dto, this.author.resolve(), file);
  }
}