import {
  Controller,
  Post,
  Body,
  UploadedFile,
  UseInterceptors,
  ParseFilePipe,
  MaxFileSizeValidator,
  FileTypeValidator,
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
import { ErrorResponseDto } from '../dto/error-response.dto';
import { CreateMaterialResponseDto, MaterialStatus } from '../dto/material-response.dto';

const MAX_FILE_SIZE_BYTES = 15728640; // 15 MB

@ApiTags('Materials')
@Controller('materials')
@ApiBearerAuth()
@ApiExtraModels(ErrorResponseDto, CreateMaterialResponseDto)
export class MaterialController {
  @Post()
  @UseInterceptors(FileInterceptor('file'))
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
- **Autenticación:** Requiere header \`Authorization: Bearer <token>\`.
- **Estado de Implementación:** Respuesta simulada (Stub).
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
    description: 'Material registrado en estado PENDING_REVIEW (Respuesta Simulada / Stub).',
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
    description: 'Unauthorized - Header Authorization: Bearer <token> ausente o inválido.',
    type: ErrorResponseDto,
  })
  @ApiResponse({
    status: 404,
    description: 'Not Found - La asignatura (subjectId) o carrera no existe.',
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
          new MaxFileSizeValidator({ maxSize: MAX_FILE_SIZE_BYTES }),
          new FileTypeValidator({
            fileType:
              /(pdf|msword|wordprocessingml\.document|ms-powerpoint|presentationml\.presentation)$/i,
          }),
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
    // Reglas cruzadas segun tipo de material
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
    } else {
      // DOCUMENT, PRESENTATION, EXAM, SUMMARY exigen archivo
      if (!file) {
        throw new BadRequestException(
          `Para el tipo de material '${dto.type}' es obligatorio adjuntar un archivo local.`,
        );
      }
    }

    // Respuesta Simulada (Stub) alineada con CreateMaterialResponseDto
    return {
      status: 'success',
      isSimulatedResponse: true,
      message: 'Material registrado exitosamente en el contrato del servicio.',
      data: {
        id: 'mat_' + Date.now(),
        title: dto.title,
        description: dto.description || null,
        year: dto.year,
        type: dto.type,
        status: MaterialStatus.PENDING_REVIEW,
        subjectId: dto.subjectId,
        careerId: dto.careerId || null,
        professorId: dto.professorId || null,
        universityId: 'UNIV-UCT-01',
        fileUrl: file
          ? `https://storage.academico.cl/materials/${dto.year}/${file.originalname}`
          : null,
        fileSize: file ? file.size : null,
        mimeType: file ? file.mimetype : null,
        externalLink: dto.externalLink || null,
        createdAt: new Date().toISOString(),
      },
    };
  }
}
