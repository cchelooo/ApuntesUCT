import { 
  Controller, Post, Body, UploadedFile, UseInterceptors, 
  ParseFilePipe, MaxFileSizeValidator, FileTypeValidator, 
  PayloadTooLargeException, UnsupportedMediaTypeException, BadRequestException 
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { 
  ApiTags, ApiConsumes, ApiBearerAuth, ApiOperation, 
  ApiResponse, ApiBody 
} from '@nestjs/swagger';
import { CreateMaterialDto } from '../dto/create-material.dto';

@ApiTags('Materials')
@Controller('materials')
@ApiBearerAuth() // Requiere Authorization: Bearer <token>
export class MaterialController {

  @Post()
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Subir y registrar un nuevo material o enlace' })
  @ApiBody({ type: CreateMaterialDto })
  
  // Documentación explícita del contrato de errores solicitada
  @ApiResponse({ status: 201, description: 'Material creado exitosamente.' })
  @ApiResponse({ status: 400, description: 'Bad Request - Metadatos inválidos o esquema incorrecto.' })
  @ApiResponse({ status: 401, description: 'Unauthorized - Falta token de autenticación o es inválido.' })
  @ApiResponse({ status: 404, description: 'Not Found - El subjectId u otra referencia académica no existe.' })
  @ApiResponse({ status: 413, description: 'Payload Too Large - El archivo supera el límite de 15 MB.' })
  @ApiResponse({ status: 415, description: 'Unsupported Media Type - Formato MIME no admitido.' })
  @ApiResponse({ status: 500, description: 'Internal Server Error - Indisponibilidad o fallo interno.' })
  
  async createMaterial(
    @Body() dto: CreateMaterialDto,
    @UploadedFile(
      new ParseFilePipe({
        fileIsRequired: false, // Opcional para permitir materiales tipo LINK
        validators: [
          new MaxFileSizeValidator({ maxSize: 15 * 1024 * 1024 }), // 15 MB exactos
          // Validamos MIME para PDF, Word y PowerPoint
          new FileTypeValidator({ fileType: /(pdf|msword|wordprocessingml\.document|ms-powerpoint|presentationml\.presentation)$/i }),
        ],
        exceptionFactory: (error) => {
          // Mapeamos los errores nativos de Nest a los HTTP status solicitados en la tarea
          if (error.includes('expected size')) {
            return new PayloadTooLargeException('El archivo supera los 15 MB permitidos');
          }
          if (error.includes('expected type')) {
            return new UnsupportedMediaTypeException('Formato no admitido. Solo PDF, Word (.doc/docx) o PowerPoint (.ppt/pptx)');
          }
          return new BadRequestException(error);
        },
      })
    ) file?: Express.Multer.File,
  ) {
    
    // Validación cruzada manual: Debe existir archivo o enlace externo
    if (!file && !dto.externalLink) {
      throw new BadRequestException('Debe proporcionar un archivo local o un enlace externo (externalLink)');
    }

    // Aquí irá la inyección del caso de uso (Clean Architecture):
    // const result = await this.createMaterialUseCase.execute(dto, file);

    // Respuesta estándar de creación
    return {
      status: 'success',
      message: 'Material registrado correctamente',
      data: {
        title: dto.title,
        type: dto.type,
        year: dto.year,
        hasFile: !!file,
        fileName: file?.originalname || null,
        link: dto.externalLink || null,
        createdAt: new Date().toISOString()
      }
    };
  }
}