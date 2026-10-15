import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { isUUID } from 'class-validator';
import { MaterialAuthor } from '../../application/use-cases/create-material';

/** Contexto local temporal hasta integrar Auth; nunca interpreta tokens sin verificar. */
@Injectable()
export class MaterialAuthorProvider {
  constructor(private readonly config: ConfigService) {}

  resolve(): MaterialAuthor {
    const id = this.config.get<string>('MATERIAL_LOCAL_UPLOADER_ID');
    if (
      this.config.get<string>('NODE_ENV') !== 'development' ||
      this.config.get<string>('MATERIAL_LOCAL_AUTHOR_ENABLED') !== 'true' ||
      !id ||
      !isUUID(id)
    ) {
      throw new UnauthorizedException('Se requiere un contexto de autor válido.');
    }
    return {
      id,
      universityId: this.config.get<string>('MATERIAL_LOCAL_UNIVERSITY_ID') || null,
    };
  }
}
