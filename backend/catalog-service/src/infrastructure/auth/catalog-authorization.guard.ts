import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import {
  AccessTokenVerifier,
  extractBearerToken,
} from './access-token.verifier';

/** Verificación independiente incluso si se accede sin pasar por el Gateway. */
@Injectable()
export class CatalogAuthorizationGuard implements CanActivate {
  constructor(private readonly verifier: AccessTokenVerifier) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    if (['GET', 'HEAD', 'OPTIONS'].includes(request.method)) return true;
    const token = extractBearerToken(request.headers.authorization);
    if (!token)
      throw new UnauthorizedException(
        'Se requiere una identidad autenticada válida.',
      );
    const identity = this.verifier.verify(token);
    if (identity.role !== 'ADMIN')
      throw new ForbiddenException('Se requiere rol ADMIN.');
    return true;
  }
}
