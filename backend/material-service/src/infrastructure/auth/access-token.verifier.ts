import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { isUUID } from 'class-validator';
import {
  decode,
  verify,
  type Algorithm,
  type JwtPayload,
  type VerifyOptions,
} from 'jsonwebtoken';

/** Identidad verificada a partir de un access token firmado. */
export interface AuthenticatedIdentity {
  id: string;
  email: string | null;
  role: string | null;
}

/** Mensaje único para no revelar si el token falta, expiró o tiene firma inválida. */
export const IDENTITY_REQUIRED_MESSAGE =
  'Se requiere una identidad autenticada válida.';

const ALLOWED_ROLES = new Set(['STUDENT', 'MODERATOR', 'ADMIN']);
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * Extrae el token de `Authorization: Bearer <token>`.
 * Devuelve null cuando la cabecera no fue enviada y rechaza formatos inválidos.
 */
export function extractBearerToken(authorization?: string): string | null {
  if (authorization === undefined) return null;
  const value = authorization.trim();
  const match = /^Bearer\s+(\S+)$/i.exec(value);
  if (!match) throw new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE);
  return match[1];
}

/**
 * Verifica access tokens JWT firmados según el contrato de autorización (#445).
 *
 * - Rechaza `alg: none` y tokens marcados con `mock: true` (login simulado).
 * - Exige `sub` UUID y `exp`, y valida `iss`/`aud` cuando están configurados.
 * - En producción, con una clave de verificación configurada, `JWT_ISSUER` y
 *   `JWT_AUDIENCE` son obligatorios y el servicio no arranca sin ellos (#445).
 * - HS256 usa `JWT_ACCESS_SECRET`; RS256/ES256 usan `JWT_ACCESS_PUBLIC_KEY`.
 */
@Injectable()
export class AccessTokenVerifier {
  constructor(private readonly config: ConfigService) {
    // El contrato #445 exige validar emisor y audiencia. En producción, si hay
    // una clave de verificación, no se permite arrancar sin `JWT_ISSUER` y
    // `JWT_AUDIENCE`: de lo contrario se aceptaría un token firmado con la clave
    // correcta pero con otro `iss`/`aud`.
    if (this.isProduction() && this.isConfigured()) {
      if (!this.issuer() || !this.audience()) {
        throw new Error(
          'JWT_ISSUER y JWT_AUDIENCE son obligatorios en producción cuando la verificación de identidad está habilitada.',
        );
      }
    }
  }

  /** Indica si existe material de verificación configurado. */
  isConfigured(): boolean {
    return Boolean(this.secret() || this.publicKey());
  }

  verify(token: string): AuthenticatedIdentity {
    const decoded = decode(token, { complete: true });
    const algorithm = decoded?.header?.alg;

    if (typeof algorithm !== 'string' || algorithm.toLowerCase() === 'none') {
      throw this.invalidIdentity();
    }

    const { key, algorithms } = this.verificationKey(algorithm);
    const options: VerifyOptions = {
      algorithms,
      clockTolerance: this.clockToleranceSeconds(),
    };
    const issuer = this.issuer();
    if (issuer) options.issuer = issuer;
    const audience = this.audience();
    if (audience) options.audience = audience;

    let payload: string | JwtPayload;

    try {
      payload = verify(token, key, options);
    } catch {
      throw this.invalidIdentity();
    }

    if (typeof payload !== 'object' || payload === null) {
      throw this.invalidIdentity();
    }
    if (payload.mock === true) {
      throw this.invalidIdentity();
    }
    if (
      typeof payload.sub !== 'string' ||
      !isUUID(payload.sub) ||
      !UUID_PATTERN.test(payload.sub)
    ) {
      throw this.invalidIdentity();
    }
    if (typeof payload.exp !== 'number') {
      throw this.invalidIdentity();
    }
    if (payload.email !== undefined && typeof payload.email !== 'string') {
      throw this.invalidIdentity();
    }
    if (
      payload.role !== undefined &&
      (typeof payload.role !== 'string' || !ALLOWED_ROLES.has(payload.role))
    ) {
      throw this.invalidIdentity();
    }

    return {
      id: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : null,
      role: typeof payload.role === 'string' ? payload.role : null,
    };
  }

  private verificationKey(algorithm: string): {
    key: string;
    algorithms: Algorithm[];
  } {
    if (algorithm === 'HS256') {
      const secret = this.secret();
      if (!secret) throw this.invalidIdentity();
      return { key: secret, algorithms: ['HS256'] };
    }
    if (algorithm === 'RS256' || algorithm === 'ES256') {
      const publicKey = this.publicKey();
      if (!publicKey) throw this.invalidIdentity();
      return { key: publicKey, algorithms: [algorithm] };
    }
    // Cualquier otro algoritmo (incluido none) queda fuera del contrato.
    throw this.invalidIdentity();
  }

  private invalidIdentity(): UnauthorizedException {
    return new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE);
  }

  private secret(): string | null {
    return this.value('JWT_ACCESS_SECRET');
  }

  private publicKey(): string | null {
    const key = this.value('JWT_ACCESS_PUBLIC_KEY');
    return key ? key.replace(/\\n/g, '\n') : null;
  }

  private issuer(): string | null {
    return this.value('JWT_ISSUER');
  }

  private audience(): string | null {
    return this.value('JWT_AUDIENCE');
  }

  private isProduction(): boolean {
    return this.value('NODE_ENV') === 'production';
  }

  private clockToleranceSeconds(): number {
    const raw = this.value('JWT_CLOCK_TOLERANCE_SECONDS');
    const parsed = raw ? Number(raw) : 0;
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
  }

  private value(key: string): string | null {
    const value = this.config.get<string>(key)?.trim();
    return value ? value : null;
  }
}
