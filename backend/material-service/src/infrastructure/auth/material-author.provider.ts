import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { isUUID } from 'class-validator';
import { MaterialAuthor } from '../../application/use-cases/create-material';
import {
  AccessTokenVerifier,
  extractBearerToken,
  IDENTITY_REQUIRED_MESSAGE,
} from './access-token.verifier';

/**
 * Resuelve el autor de una subida o versión a partir de la identidad autenticada.
 *
 * Prioridad:
 * 1. `Authorization: Bearer <JWT firmado>` verificado (#446).
 * 2. Contexto local explícito solo en desarrollo (`MATERIAL_LOCAL_*`), conservado
 *    como transición mientras Auth emite tokens reales (#441).
 *
 * Un token presente pero inválido nunca cae al contexto local.
 */
@Injectable()
export class MaterialAuthorProvider {
  constructor(
    private readonly config: ConfigService,
    private readonly tokens: AccessTokenVerifier,
  ) {
    if (this.isProduction() && this.isLocalAuthorEnabled()) {
      throw new Error(
        'MATERIAL_LOCAL_AUTHOR_ENABLED no puede habilitarse con NODE_ENV=production.',
      );
    }
  }

  resolve(authorization?: string): MaterialAuthor {
    const token = extractBearerToken(authorization);

    if (token) {
      const identity = this.tokens.verify(token);
      return {
        id: identity.id,
        // El contrato de #445 no define universidad en el token; no se inventa.
        universityId: null,
      };
    }

    return this.resolveLocalAuthor();
  }

  private resolveLocalAuthor(): MaterialAuthor {
    const id = this.config.get<string>('MATERIAL_LOCAL_UPLOADER_ID');
    if (
      !this.isLocalAuthorEnabled() ||
      !this.isDevelopment() ||
      !id ||
      !isUUID(id)
    ) {
      throw new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE);
    }
    return {
      id,
      universityId:
        this.config.get<string>('MATERIAL_LOCAL_UNIVERSITY_ID') || null,
    };
  }

  private isLocalAuthorEnabled(): boolean {
    return this.config.get<string>('MATERIAL_LOCAL_AUTHOR_ENABLED') === 'true';
  }

  private isDevelopment(): boolean {
    return this.config.get<string>('NODE_ENV') === 'development';
  }

  private isProduction(): boolean {
    return this.config.get<string>('NODE_ENV') === 'production';
  }
}
