import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { RequestHandler } from 'express';
import {
  AccessTokenVerifier,
  extractBearerToken,
} from './access-token.verifier';

/** Se ejecuta antes del proxy: los guards de controladores no cubren middleware. */
export function authorizeWrites(
  config: ConfigService,
  minimumRole: 'STUDENT' | 'MODERATOR' | 'ADMIN',
): RequestHandler {
  const verifier = new AccessTokenVerifier(config);
  const rank = { STUDENT: 0, MODERATOR: 1, ADMIN: 2 };
  return (req, _res, next) => {
    if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) return next();
    try {
      const token = extractBearerToken(req.headers.authorization);
      if (!token)
        throw new UnauthorizedException(
          'Se requiere una identidad autenticada válida.',
        );
      const identity = verifier.verify(token);
      if (
        !identity.role ||
        rank[identity.role as keyof typeof rank] < rank[minimumRole]
      ) {
        throw new ForbiddenException('Permisos insuficientes.');
      }
      next();
    } catch (error) {
      next(error);
    }
  };
}
