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
  AuthenticatedIdentity,
  extractBearerToken,
  IDENTITY_REQUIRED_MESSAGE,
} from './access-token.verifier';

export type ModerationRequest = Request & { identity: AuthenticatedIdentity };

@Injectable()
export class MaterialModeratorGuard implements CanActivate {
  constructor(private readonly tokens: AccessTokenVerifier) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<ModerationRequest>();
    const token = extractBearerToken(request.headers.authorization);
    if (!token) throw new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE);
    const identity = this.tokens.verify(token);
    if (identity.role !== 'MODERATOR' && identity.role !== 'ADMIN') {
      throw new ForbiddenException('Se requiere rol MODERATOR o ADMIN.');
    }
    request.identity = identity;
    return true;
  }
}
