import {
  Controller,
  Post,
  Body,
  UploadedFile,
  UseInterceptors,
  ParseFilePipe,
  MaxFileSizeValidator,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
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
import {
  CreateMaterialDto,
  MaterialType,
  MATERIAL_TYPE_DESCRIPTION,
  MATERIAL_MIME_TYPES,
  MATERIAL_FILE_DESCRIPTION,
} from '../dto/create-material.dto';
import { MaterialFileTypeValidator } from '../validators/material-file-type.validator';
import { ErrorResponseDto } from '../dto/error-response.dto';
import { CreateMaterialResponseDto } from '../dto/material-response.dto';

import { CreateMaterial } from '../../application/use-cases/create-material';
import { MaterialAuthorProvider } from '../../infrastructure/auth/material-author.provider';

const MAX_FILE_SIZE_BYTES = 15728640; // 15 MB

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
  // Multer corta la recepción antes de cargar un archivo arbitrariamente grande.
  // Sus límites y MaxFileSizeValidator son exclusivos: se permite exactamente 15 MB.
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: MAX_FILE_SIZE_BYTES + 1, files: 1 } }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiOperation({
    summary: 'Subir y registrar un nuevo material o enlace académico',
    description: `
**REGLAS Y CONTRATO DE NEGOCIO:**
- **Estado Inicial:** Todo material creado inicia en estado \`PENDING_REVIEW\`.
- **Identificadores Académicos:**
  - \`subjectId\` (Obligatorio) y \`careerId\` (Opcional) vinculan el recurso al catálogo académico.
  - \`professorId\` (Opcional) almacena el identificador único del docente.
  - \`universityId\` se deriva automáticamente del contexto institucional/autenticación.
- **Reglas de Archivo / Enlace por Tipo (\`type\`):**
  - **LINK:** Requiere de manera obligatoria \`externalLink\` (validado como URL). No acepta archivo binario.
  - **DOCUMENT, PRESENTATION, EXAM, SUMMARY:** Requieren obligatoriamente un **archivo local** (file). Se permite incluir \`externalLink\` como URL de respaldo secundaria.
- **Límite de Archivo:** Máximo **15 MB (15,728,640 bytes)**.
- **MIMEs Permitidos:** ${MATERIAL_MIME_TYPES.join(', ')}.
- **Relación del tipo con persistencia/listado:** ${MATERIAL_TYPE_DESCRIPTION}
- **Autenticación:** Integración pendiente. El token simulado de Auth no autoriza esta operación.
- **Estado de Implementación:** Persistencia real en PostgreSQL y MinIO.
- **Autor temporal:** Solo desarrollo con contexto local habilitado por entorno; Auth real pendiente.
    `,
  })
  @ApiBody({
    description:
      'Metadatos en formato multipart/form-data y archivo adjunto opcional/obligatorio según type.',
    schema: {
      type: 'object',
      properties: {
        title: { type: 'string', example: 'Guía Práctica de Álgebra Lineal' },
        description: {
          type: 'string',
          example: 'Ejercicios resueltos sobre valores y vectores propios.',
        },
        year: { type: 'string', example: '2026' },
        type: {
          type: 'string',
          enum: Object.values(MaterialType),
          example: MaterialType.DOCUMENT,
          description: MATERIAL_TYPE_DESCRIPTION,
        },
        subjectId: { type: 'string', example: 'SUBJ-102' },
        careerId: { type: 'string', example: 'CAREER-INF-01' },
        professorId: { type: 'string', example: 'prof_88321' },
        externalLink: { type: 'string', example: 'https://drive.google.com/file/d/xyz/view' },
        file: { type: 'string', format: 'binary', description: MATERIAL_FILE_DESCRIPTION },
      },
      required: ['title', 'year', 'type', 'subjectId'],
    },
    examples: {
      conArchivoLocal: {
        summary: 'Opción A: Documento/Examen/Resumen (Requiere Archivo)',
        value: {
          title: 'Apunte de Redes IPv4',
          description: 'Documento PDF con subnetting',
          year: '2026',
          type: MaterialType.DOCUMENT,
          subjectId: 'NET-201',
          careerId: 'INF-01',
          professorId: 'prof_102',
          file: '(binary)',
        },
      },
      conEnlaceExterno: {
        summary: 'Opción B: Enlace Externo (Requiere URL válidamente formateada)',
        value: {
          title: 'Clase Grabada - Arquitectura Django',
          description: 'Video explicativo en Drive/YouTube',
          year: '2026',
          type: MaterialType.LINK,
          subjectId: 'SWE-301',
          professorId: 'prof_305',
          externalLink: 'https://drive.google.com/file/d/12345/view',
        },
      },
    },
  })
  @ApiResponse({
    status: 201,
    description: 'Material persistido en estado PENDING_REVIEW.',
    type: CreateMaterialResponseDto,
  })
  @ApiResponse({
    status: 400,
    description:
      'Bad Request - Error de validación en metadatos, formato de URL inválido o incumplimiento de regla file/link según el type.',
    type: ErrorResponseDto,
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized - Contexto de autor no disponible.',
    type: ErrorResponseDto,
  })
  @ApiResponse({
    status: 413,
    description:
      'Payload Too Large - El archivo supera el tamaño máximo permitidos de 15 MB (15728640 bytes).',
    type: ErrorResponseDto,
  })
  @ApiResponse({
    status: 415,
    description: 'Unsupported Media Type - Formato de archivo no admitido.',
    type: ErrorResponseDto,
  })
  @ApiResponse({
    status: 500,
    description: 'Internal Server Error - Error no controlado.',
    type: ErrorResponseDto,
  })
  @ApiResponse({
    status: 502,
    description: 'Bad Gateway - Indisponibilidad de servicios externos.',
    type: ErrorResponseDto,
  })
  async createMaterial(
    @Body() dto: CreateMaterialDto,
    @UploadedFile(
      new ParseFilePipe({
        fileIsRequired: false,
        validators: [
          new MaxFileSizeValidator({ maxSize: MAX_FILE_SIZE_BYTES + 1 }),
          new MaterialFileTypeValidator(),
        ],
        exceptionFactory: (error) => {
          if (error.includes('expected size')) {
            return new PayloadTooLargeException(
              `El archivo excede el tamaño máximo permitido de 15 MB (${MAX_FILE_SIZE_BYTES} bytes).`,
            );
          }
          if (error.includes('expected type')) {
            return new UnsupportedMediaTypeException(
              'Tipo de archivo no admitido. Formatos válidos: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).',
            );
          }
          return new BadRequestException(error);
        },
      }),
    )
    file?: Express.Multer.File,
  ) {
    return this.create.execute(dto, this.author.resolve(), file);
  }
}
