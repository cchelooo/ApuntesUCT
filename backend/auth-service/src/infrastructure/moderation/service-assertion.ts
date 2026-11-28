// Quality internal profile v1. Keep these copies identical across Auth/Quality/Material.
import { createHash, randomUUID } from 'node:crypto';
import { sign, verify, JwtPayload } from 'jsonwebtoken';
import { HttpException } from '@nestjs/common';
export type Actor = { id: string; role: string; authorizedAt: string };
export interface ServiceContext extends JwtPayload {
  actorId: string;
  actorRole: string;
  authorizedAt: string;
  resource: string;
  scope: string;
  bodyHash: string;
  operationId?: string;
}
export function fault(
  statusCode: number,
  code: string,
  message: string,
): HttpException {
  return new HttpException({ statusCode, code, message }, statusCode);
}
export function digest(value: unknown): string {
  const stable = (v: unknown): unknown =>
    Array.isArray(v)
      ? v.map(stable)
      : v && typeof v === 'object'
        ? Object.fromEntries(
            Object.entries(v)
              .sort(([a], [b]) => a.localeCompare(b))
              .map(([k, x]) => [k, stable(x)]),
          )
        : v;
  return createHash('sha256')
    .update(JSON.stringify(stable(value)))
    .digest('hex');
}
export const uuid = (x: unknown): x is string =>
  typeof x === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    x,
  );
export function serviceToken(
  key: string,
  audience: string,
  scope: string,
  resource: string,
  actor: Actor,
  body: unknown = null,
  operationId?: string,
): string {
  return sign(
    {
      actorId: actor.id,
      actorRole: actor.role,
      authorizedAt: actor.authorizedAt,
      scope,
      resource,
      bodyHash: digest(body),
      ...(operationId ? { operationId } : {}),
    },
    key.replace(/\\n/g, '\n'),
    {
      algorithm: 'RS256',
      issuer: 'quality-service',
      subject: 'quality-service',
      audience,
      expiresIn: 60,
      jwtid: randomUUID(),
    },
  );
}
export function verifyService(
  authorization: string | undefined,
  key: string | undefined,
  audience: string,
  scope: string,
  resource: string,
  body: unknown = null,
): ServiceContext {
  const token = /^Bearer ([^ ]+)$/i.exec(authorization ?? '')?.[1];
  let c: ServiceContext;
  try {
    if (!key || !token) throw new Error();
    const p = verify(token, key.replace(/\\n/g, '\n'), {
      algorithms: ['RS256'],
      issuer: 'quality-service',
      subject: 'quality-service',
      audience,
      clockTolerance: 0,
    });
    if (typeof p !== 'object') throw new Error();
    c = p as ServiceContext;
    const now = Math.floor(Date.now() / 1000);
    if (
      !Number.isInteger(c.iat) ||
      !Number.isInteger(c.exp) ||
      c.iat! > now + 5 ||
      c.exp! - c.iat! > 60 ||
      c.exp! <= c.iat! ||
      !uuid(c.jti) ||
      !uuid(c.actorId) ||
      !['STUDENT', 'MODERATOR', 'ADMIN'].includes(c.actorRole) ||
      typeof c.authorizedAt !== 'string' ||
      !Number.isFinite(Date.parse(c.authorizedAt)) ||
      Date.parse(c.authorizedAt) > Date.now() + 5000 ||
      c.resource !== resource ||
      c.bodyHash !== digest(body)
    )
      throw new Error();
  } catch {
    throw fault(401, 'SERVICE_UNAUTHENTICATED', 'Credencial interna inválida.');
  }
  if (c.scope !== scope)
    throw fault(403, 'SERVICE_FORBIDDEN', 'Permiso interno insuficiente.');
  return c;
}
