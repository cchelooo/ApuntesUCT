import { FileTypeValidator, FileValidator } from '@nestjs/common';
import * as CFB from 'cfb';

const CFB_SIGNATURE = Buffer.from([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]);

/** Detects the allowed formats from content, never from the supplied filename/MIME. */
export class MaterialFileTypeValidator extends FileValidator<
  Record<string, never>,
  Express.Multer.File
> {
  private readonly modernFormats = new FileTypeValidator({
    fileType:
      /^(application\/pdf|application\/vnd\.openxmlformats-officedocument\.(wordprocessingml\.document|presentationml\.presentation))$/,
    overrideMimeType: true,
  });

  constructor() {
    super({});
  }

  async isValid(file?: Express.Multer.File): Promise<boolean> {
    if (!file?.buffer) return false;
    if (!file.buffer.subarray(0, CFB_SIGNATURE.length).equals(CFB_SIGNATURE)) {
      return this.modernFormats.isValid(file);
    }
    // DOC and PPT share an OLE/CFB header with unrelated formats such as XLS.
    // Parse the container and require their identifying root streams.
    try {
      const container = CFB.read(file.buffer, { type: 'buffer' });
      const hasStream = (name: string) => {
        const entry = CFB.find(container, `/${name}`);
        return entry?.type === 2 && entry.content.length > 0;
      };
      const isWord = hasStream('WordDocument') && (hasStream('0Table') || hasStream('1Table'));
      const isPowerPoint = hasStream('PowerPoint Document') && hasStream('Current User');
      if (isWord === isPowerPoint || hasStream('Workbook') || hasStream('Book')) return false;
      file.mimetype = isWord ? 'application/msword' : 'application/vnd.ms-powerpoint';
      return true;
    } catch {
      return false;
    }
  }

  buildErrorMessage(): string {
    return 'Validation failed (expected type: PDF, DOC, DOCX, PPT or PPTX)';
  }
}
