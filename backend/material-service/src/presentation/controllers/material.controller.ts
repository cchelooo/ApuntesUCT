import { 
  Controller, Post, Body, UploadedFile, UseInterceptors, 
  ParseFilePipe, MaxFileSizeValidator, FileTypeValidator, 
  PayloadTooLargeException, UnsupportedMediaTypeException, BadRequestException 
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { 
  ApiTags, ApiConsumes, ApiBearerAuth, ApiOperation, 
  ApiResponse, ApiBody, ApiExtraModels 
} from '@nestjs/swagger';
import { CreateMaterialDto, MaterialType } from '../dto/create-material.dto';
import { ErrorResponseDto } from '../dto/error-response.dto';

// Límite exacto de 15 MB en bytes: 15 * 1024 * 1024
const MAX_FILE_SIZE_BYTES = 15728640;

// Lista explícita de MIMEs permitidos
const ALLOWED_MIME_TYPES = [
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
];

@ApiTags('Materials')
@Controller('materials')
@ApiBearerAuth()
@ApiExtraModels(ErrorResponseDto)
export class MaterialController {

  @Post()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ 
    summary: 'Subir y registrar un nuevo material o enlace académico',
    description: `
**REGLAS Y CONTRATO DE NEGOCIO:**
- **Atributos Derivados:** 'id', 'createdAt', 'fileSize' y 'fileUrl' son calculados internamente por el servidor tras procesar la petición.
- **Relación Archivo / Enlace / Type:**
  - Si **type** es 'LINK', el campo **externalLink** es obligatorio y el archivo se omite.
  - Si **type** es 'DOCUMENT' o 'PRESENTATION', se debe enviar un **file**. Se permite adjuntar **externalLink** como espejo o referencia secundaria opcional.
  - No se permite enviar una petición sin 'file' ni 'externalLink'.
- **Límite de Archivo:** Máximo **15 MB (15,728,640 bytes)**.
- **MIME Types Admitidos:**
  - PDF: \`application/pdf\`
  - Word: \`application/msword\`, \`application/vnd.openxmlformats-officedocument.wordprocessingml.document\`
  - PowerPoint: \`application/vnd.ms-powerpoint\`, \`application/vnd.openxmlformats-officedocument.presentationml.presentation\`
- **Autenticación:** Requiere header \`Authorization: Bearer <token>\`.
- **Estado de Implementación:** *Respuesta simulada (Stub)* para validación de integración Frontend/Mobile.
    `
  })
  @ApiBody({
    description: 'Metadatos en campos de texto y archivo adjunto binario.',
    schema: {
      type: 'object',
      properties: {
        title: { type: 'string', example: 'Guía Práctica de Álgebra Lineal' },
        description: { type: 'string', example: 'Ejercicios resueltos sobre valores y vectores propios.' },
        year: { type: 'string', example: '2026' },
        type: { type: 'string', enum: Object.values(MaterialType), example: MaterialType.DOCUMENT },
        subjectId: { type: 'string', example: 'SUBJ-102' },
        careerId: { type: 'string', example: 'CAREER-INF-01' },
        professor: { type: 'string', example: 'Dr. Roberto Gómez' },
        externalLink: { type: 'string', example: 'https://drive.google.com/file/d/xyz/view' },
        file: { type: 'string', format: 'binary', description: 'Archivo binario local (Máx 15MB)' },
      },
      required: ['title', 'year', 'type', 'subjectId'],
    },
    examples: {
      conArchivoLocal: {
        summary: 'Opción A: Subida de Archivo Local (PDF/Word/PPT)',
        value: {
          title: 'Apunte de Redes IPv4',
          description: 'Documento PDF con subnetting y ejemplos',
          year: '2026',
          type: MaterialType.DOCUMENT,
          subjectId: 'NET-201',
          careerId: 'INF-01',
          professor: 'Ing. Carlos Pérez',
          file: '(binary)',
        },
      },
      conEnlaceExterno: {
        summary: 'Opción B: Enlace Externo (Google Drive / YouTube / Web)',
        value: {
          title: 'Clase Grabada - Arquitectura Django',
          description: 'Video explicativo en repositorio externo',
          year: '2026',
          type: MaterialType.LINK,
          subjectId: 'SWE-301',
          professor: 'Dra. María Torres',
          externalLink: 'https://drive.google.com/file/d/12345/view',
        },
      },
    },
  })
  @ApiResponse({
    status: 201,
    description: 'Material registrado correctamente. (Respuesta Simulada / Stub)',
    schema: {
      type: 'object',
      example: {
        status: 'success',
        isSimulatedResponse: true,
        message: 'Material registrado exitosamente en el contrato del servicio.',
        data: {
          id: 'mat_987654321',
          title: 'Guía Práctica de Álgebra Lineal',
          description: 'Ejercicios resueltos sobre valores y vectores propios.',
          year: '2026',
          type: 'DOCUMENT',
          subjectId: 'SUBJ-102',
          careerId: 'CAREER-INF-01',
          professor: 'Dr. Roberto Gómez',
          fileUrl: 'https://storage.academico.cl/materials/2026/mat_987654321.pdf',
          fileSize: 2048500,
          mimeType: 'application/pdf',
          externalLink: null,
          createdAt: '2026-10-05T14:00:00.000Z',
        },
      },
    },
  })
  @ApiResponse({
    status: 400,
    description: 'Bad Request - Metadatos inválidos, formato de year erróneo o ausencia de archivo y enlace.',
    type: ErrorResponseDto,
    example: {
      statusCode: 400,
      error: 'Bad Request',
      message: ['year debe ser un año válido de 4 dígitos (ej. 2026)', 'Debe proporcionar al menos un archivo local o un enlace externo.'],
      timestamp: '2026-10-05T14:00:00.000Z',
      path: '/api/v1/materials',
    },
  })
  @ApiResponse({
    status: 401,
    description: 'Unauthorized - Cabecera Authorization: Bearer <token> ausente o inválida.',
    type: ErrorResponseDto,
    example: {
      statusCode: 401,
      error: 'Unauthorized',
      message: 'No se proporcionó un token de autenticación válido.',
      timestamp: '2026-10-05T14:00:00.000Z',
      path: '/api/v1/materials',
    },
  })
  @ApiResponse({
    status: 404,
    description: 'Not Found - La asignatura (subjectId) o carrera referenciada no existe.',
    type: ErrorResponseDto,
    example: {
      statusCode: 404,
      error: 'Not Found',
      message: 'La asignatura con ID SUBJ-102 no fue encontrada en el sistema.',
      timestamp: '2026-10-05T14:00:00.000Z',
      path: '/api/v1/materials',
    },
  })
  @ApiResponse({
    status: 413,
    description: 'Payload Too Large - El archivo supera el peso máximo de 15 MB (15,728,640 bytes).',
    type: ErrorResponseDto,
    example: {
      statusCode: 413,
      error: 'Payload Too Large',
      message: 'El archivo excede el tamaño máximo permitido de 15 MB (15728640 bytes).',
      timestamp: '2026-10-05T14:00:00.000Z',
      path: '/api/v1/materials',
    },
  })
  @ApiResponse({
    status: 415,
    description: 'Unsupported Media Type - Tipo MIME no admitido.',
    type: ErrorResponseDto,
    example: {
      statusCode: 415,
      error: 'Unsupported Media Type',
      message: 'Tipo de archivo no admitido. Formatos válidos: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).',
      timestamp: '2026-10-05T14:00:00.000Z',
      path: '/api/v1/materials',
    },
  })
  @ApiResponse({
    status: 500,
    description: 'Internal Server Error - Error no controlado en el servidor de materiales.',
    type: ErrorResponseDto,
    example: {
      statusCode: 500,
      error: 'Internal Server Error',
      message: 'Ocurrió un error inesperado al procesar la solicitud.',
      timestamp: '2026-10-05T14:00:00.000Z',
      path: '/api/v1/materials',
    },
  })
  @ApiResponse({
    status: 502,
    description: 'Bad Gateway - Fallo de comunicación con el servicio de almacenamiento o base de datos.',
    type: ErrorResponseDto,
    example: {
      statusCode: 502,
      error: 'Bad Gateway',
      message: 'No se pudo establecer conexión con el proveedor de almacenamiento persistente.',
      timestamp: '2026-10-05T14:00:00.000Z',
      path: '/api/v1/materials',
    },
  })
  async createMaterial(
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
    // Validaciones cruzadas de regla de negocio
    if (!file && !dto.externalLink) {
      throw new BadRequestException('Debe proporcionar al menos un archivo local o un enlace externo (externalLink).');
    }

    if (dto.type === MaterialType.LINK && !dto.externalLink) {
      throw new BadRequestException('Para materiales de tipo LINK es obligatorio especificar externalLink.');
    }

    // Respuesta simulada (Stub) explícita
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
        subjectId: dto.subjectId,
        careerId: dto.careerId || null,
        professor: dto.professor || null,
        fileUrl: file ? `https://storage.academico.cl/materials/${dto.year}/${file.originalname}` : null,
        fileSize: file ? file.size : null,
        mimeType: file ? file.mimetype : null,
        externalLink: dto.externalLink || null,
        createdAt: new Date().toISOString(),
      },
    };
  }
}