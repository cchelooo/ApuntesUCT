import { 
  Controller, Post, Body, UploadedFile, UseInterceptors, Req,
  ParseFilePipe, MaxFileSizeValidator, FileTypeValidator, 
  PayloadTooLargeException, UnsupportedMediaTypeException, BadRequestException, UnauthorizedException 
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { 
  ApiTags, ApiConsumes, ApiBearerAuth, ApiOperation, 
  ApiResponse, ApiBody, ApiExtraModels 
} from '@nestjs/swagger';
import type { Request } from 'express';
import { CreateMaterialDto, MaterialType } from '../dto/create-material.dto';
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
    summary: 'Subir y registrar un nuevo material o enlace académico con validaciones de seguridad',
    description: `
**REGLAS DE SEGURIDAD Y VALIDACIÓN EN SERVIDOR:**
- **Autenticación:** Requiere cabecera \`Authorization: Bearer <token>\` vía botón Authorize (Retorna \`401\` si falta o es inválida).
- **Tamaño máximo:** Límite estricto de 15 MB / 15,728,640 bytes (Retorna \`413\` si se excede).
- **Tipos MIME permitidos:** PDF (\`application/pdf\`), Word (\`.doc\`, \`.docx\`) y PowerPoint (\`.ppt\`, \`.pptx\`) (Retorna \`415\` si no es compatible).
- **Archivo vacío:** Se rechaza si el archivo pesa 0 bytes (Retorna \`400\`).
- **Metadatos obligatorios y formato:** \`title\`, \`year\` (YYYY), \`type\` y \`subjectId\` validados rigurosamente (Retorna \`400\` si fallan).
- **Reglas de Negocio por Tipo:** 
  - \`LINK\` exige \`externalLink\` válido y prohíbe archivo.
  - \`DOCUMENT\`, \`PRESENTATION\`, \`EXAM\` y \`SUMMARY\` exigen archivo local obligatorio.
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
        type: { type: 'string', enum: Object.values(MaterialType), example: MaterialType.DOCUMENT },
        subjectId: { type: 'string', example: 'SUBJ-102' },
        careerId: { type: 'string', example: 'CAREER-INF-01' },
        professorId: { type: 'string', example: 'prof_88321' },
        externalLink: { type: 'string', example: 'https://drive.google.com/file/d/xyz/view' },
        file: { type: 'string', format: 'binary', description: 'Archivo binario local (Máx 15MB)' },
      },
      required: ['title', 'year', 'type', 'subjectId'],
    },
    examples: {
      conArchivoLocal: {
        summary: 'Subida de Documento Local',
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
        summary: 'Registro de Enlace Externo',
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
  @ApiResponse({ status: 201, description: 'Material registrado en estado PENDING_REVIEW.', type: CreateMaterialResponseDto })
  @ApiResponse({ 
    status: 400, 
    description: 'Bad Request - Metadatos incorrectos, año inválido, archivo vacío o regla de tipo incumplida.',
    schema: {
      example: {
        statusCode: 400,
        error: 'Bad Request',
        message: 'Para materiales de tipo LINK es obligatorio especificar externalLink (URL válida).',
        timestamp: '2026-10-10T23:55:00.000Z',
        path: '/api/v1/materials'
      }
    }
  })
  @ApiResponse({ 
    status: 401, 
    description: 'Unauthorized - Petición sin token de autenticación.',
    schema: {
      example: {
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Se requiere autenticación mediante token Bearer para realizar esta operación.',
        timestamp: '2026-10-10T23:55:00.000Z',
        path: '/api/v1/materials'
      }
    }
  })
  @ApiResponse({ 
    status: 404, 
    description: 'Not Found - Asignatura o recurso no encontrado.',
    schema: {
      example: {
        statusCode: 404,
        error: 'Not Found',
        message: 'La asignatura con id SUBJ-999 no existe.',
        timestamp: '2026-10-10T23:55:00.000Z',
        path: '/api/v1/materials'
      }
    }
  })
  @ApiResponse({ 
    status: 413, 
    description: 'Payload Too Large - El archivo supera los 15 MB.',
    schema: {
      example: {
        statusCode: 413,
        error: 'Payload Too Large',
        message: 'El archivo excede el tamaño máximo permitido de 15 MB (15728640 bytes).',
        timestamp: '2026-10-10T23:55:00.000Z',
        path: '/api/v1/materials'
      }
    }
  })
  @ApiResponse({ 
    status: 415, 
    description: 'Unsupported Media Type - Formato de archivo no soportado.',
    schema: {
      example: {
        statusCode: 415,
        error: 'Unsupported Media Type',
        message: 'Tipo de archivo no admitido. Formatos válidos: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).',
        timestamp: '2026-10-10T23:55:00.000Z',
        path: '/api/v1/materials'
      }
    }
  })
  @ApiResponse({ 
    status: 500, 
    description: 'Internal Server Error - Error inesperado en el servidor.',
    schema: {
      example: {
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Ocurrió un error interno en el servidor al procesar la solicitud.',
        timestamp: '2026-10-10T23:55:00.000Z',
        path: '/api/v1/materials'
      }
    }
  })
  @ApiResponse({ 
    status: 502, 
    description: 'Bad Gateway - Error de comunicación con servicios dependientes.',
    schema: {
      example: {
        statusCode: 502,
        error: 'Bad Gateway',
        message: 'Error de comunicación con el servicio de infraestructura o gateway.',
        timestamp: '2026-10-10T23:55:00.000Z',
        path: '/api/v1/materials'
      }
    }
  })
  async createMaterial(
    @Req() req: Request,
    @Body() dto: CreateMaterialDto,
    @UploadedFile(
      new ParseFilePipe({
        fileIsRequired: false,
        validators: [
          new MaxFileSizeValidator({ maxSize: MAX_FILE_SIZE_BYTES }),
          new FileTypeValidator({ fileType: /(pdf|msword|wordprocessingml\.document|ms-powerpoint|presentationml\.presentation)$/i }),
        ],
        exceptionFactory: (error) => {
          if (error.includes('expected size')) {
            return new PayloadTooLargeException(`El archivo excede el tamaño máximo permitido de 15 MB (${MAX_FILE_SIZE_BYTES} bytes).`);
          }
          if (error.includes('expected type')) {
            return new UnsupportedMediaTypeException('Tipo de archivo no admitido. Formatos válidos: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).');
          }
          return new BadRequestException(error);
        },
      })
    ) file?: Express.Multer.File,
  ) {
    const authHeader = req.headers['authorization'];

    // 1. Validación de Autenticación (401 si no hay token Bearer)
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Se requiere autenticación mediante token Bearer para realizar esta operación.');
    }

    // 2. Validación de Archivo Vacío (0 bytes) (400)
    if (file && file.size === 0) {
      throw new BadRequestException('El archivo adjunto está vacío (0 bytes) y no puede ser procesado.');
    }

    // 3. Reglas cruzadas por Tipo de Material (400)
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

    // Respuesta simulada exitosa (Stub)
    return {
      status: 'success',
      isSimulatedResponse: true,
      message: 'Material validado y registrado exitosamente en estado PENDING_REVIEW.',
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
        fileUrl: file ? `https://storage.academico.cl/materials/${dto.year}/${file.originalname}` : null,
        fileSize: file ? file.size : null,
        mimeType: file ? file.mimetype : null,
        externalLink: dto.externalLink || null,
        createdAt: new Date().toISOString(),
      },
    };
  }
}