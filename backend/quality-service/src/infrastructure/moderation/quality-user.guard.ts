import { CanActivate, ExecutionContext, Injectable, HttpException } from '@nestjs/common';
import { verify } from 'jsonwebtoken';
import { Request } from 'express';
import { Actor, fault, serviceToken, uuid } from './service-assertion';
export type UserRequest = Request & { identity: Actor; requestId: string };
@Injectable()
export class QualityUserGuard implements CanActivate {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<UserRequest>();
    const token = /^Bearer\s+(\S+)$/i.exec(req.headers.authorization ?? '')?.[1];
    let actor: Actor;
    try {
      if (
        !token ||
        !process.env.JWT_ACCESS_PUBLIC_KEY ||
        !process.env.JWT_ISSUER ||
        !process.env.JWT_AUDIENCE
      )
        throw new Error();
      const c = verify(token, process.env.JWT_ACCESS_PUBLIC_KEY.replace(/\\n/g, '\n'), {
        algorithms: ['RS256'],
        issuer: process.env.JWT_ISSUER,
        audience: process.env.JWT_AUDIENCE,
      });
      if (
        typeof c !== 'object' ||
        !uuid(c.sub) ||
        !Number.isInteger(c.exp) ||
        !Number.isInteger(c.iat) ||
        c.mock !== undefined ||
        typeof c.role !== 'string' ||
        !['STUDENT', 'MODERATOR', 'ADMIN'].includes(c.role)
      )
        throw new Error();
      actor = { id: c.sub.toLowerCase(), role: c.role, authorizedAt: new Date().toISOString() };
    } catch {
      throw fault(401, 'UNAUTHENTICATED', 'Se requiere una identidad autenticada válida.');
    }
    if (process.env.QUALITY_MODERATION_ENABLED !== 'true')
      throw fault(503, 'DEPENDENCY_UNAVAILABLE', 'Moderación no habilitada.');
    const key = process.env.QUALITY_SERVICE_PRIVATE_KEY,
      base = process.env.AUTH_INTERNAL_URL;
    if (!key || !base || (process.env.NODE_ENV === 'production' && !base.startsWith('https://')))
      throw fault(503, 'DEPENDENCY_UNAVAILABLE', 'Verificación de identidad no configurada.');
    try {
      const body = { accessToken: token };
      const resource = '/internal/v1/quality/identity';
      const r = await fetch(new URL(resource, base), {
        method: 'POST',
        redirect: 'error',
        signal: AbortSignal.timeout(2000),
        headers: {
          'Content-Type': 'application/json',
          Authorization:
            'Bearer ' +
            serviceToken(key, 'auth-service', 'auth:identity:read', resource, actor, body),
        },
        body: JSON.stringify(body),
      });
      if (!r.ok) {
        const error = (await r.json()) as { code?: string };
        if (error.code === 'SERVICE_UNAUTHENTICATED' || error.code === 'SERVICE_FORBIDDEN')
          throw fault(503, 'DEPENDENCY_UNAVAILABLE', 'Credencial de servicio no disponible.');
      }
      if (r.status === 401) throw fault(401, 'UNAUTHENTICATED', 'Credencial inválida o revocada.');
      if (r.status === 403) throw fault(403, 'FORBIDDEN', 'Cuenta sin autorización.');
      if (!r.ok)
        throw fault(503, 'DEPENDENCY_UNAVAILABLE', 'No se pudo verificar la identidad vigente.');
      const current = (await r.json()) as { id: string; role: string; active: boolean };
      if (
        current.id !== actor.id ||
        current.active !== true ||
        !['STUDENT', 'MODERATOR', 'ADMIN'].includes(current.role)
      )
        throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Identidad inconsistente.');
      req.identity = { id: current.id, role: current.role, authorizedAt: new Date().toISOString() };
    } catch (e) {
      if (e instanceof HttpException) throw e;
      throw fault(503, 'DEPENDENCY_UNAVAILABLE', 'Auth no disponible.');
    }
    if (!['MODERATOR', 'ADMIN'].includes(req.identity.role))
      throw fault(403, 'FORBIDDEN', 'Se requiere MODERATOR o ADMIN.');
    return true;
  }
}
