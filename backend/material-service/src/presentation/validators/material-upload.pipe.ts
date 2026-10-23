import {
  ParseFilePipe,
  MaxFileSizeValidator,
  FileValidator,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
  BadRequestException,
} from '@nestjs/common';
import { MaterialFileTypeValidator } from './material-file-type.validator';

export const MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024; // 15 MiB: 15.728.640 bytes.

/** Rechaza archivos vacíos antes del validador MIME; permite ausencia de archivo para LINK. */
class EmptyFileValidator extends FileValidator<object> {
  public isValid(file?: Express.Multer.File): boolean {
    if (!file) return true;
    return file.size > 0;
  }

  public buildErrorMessage(): string {
    return 'El archivo adjunto está vacío (0 bytes) y no puede ser procesado.';
  }
}

export function materialUploadPipe(fileIsRequired = false) {
  return new ParseFilePipe({
    fileIsRequired,
    validators: [
      new EmptyFileValidator({}),
      new MaxFileSizeValidator({ maxSize: MAX_FILE_SIZE_BYTES + 1 }),
      new MaterialFileTypeValidator(),
    ],
    exceptionFactory: (error) => {
      if (error.includes('vacío') || error.includes('empty')) {
        return new BadRequestException(
          'El archivo adjunto está vacío (0 bytes) y no puede ser procesado.',
        );
      }
      if (error.includes('expected size') || error.includes('file size')) {
        return new PayloadTooLargeException(
          `El archivo excede el tamaño máximo permitido de 15 MB (${MAX_FILE_SIZE_BYTES} bytes).`,
        );
      }
      if (
        error.includes('expected type') ||
        error.includes('file type') ||
        error.includes('Tipo de archivo')
      ) {
        return new UnsupportedMediaTypeException(
          'Tipo de archivo no admitido. Formatos válidos: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).',
        );
      }
      return new BadRequestException(error);
    },
  });
}
