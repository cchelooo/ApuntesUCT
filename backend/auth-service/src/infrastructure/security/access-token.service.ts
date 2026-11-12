import { Injectable, UnauthorizedException } from '@nestjs/common';
import { createPrivateKey, createPublicKey, KeyObject } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { sign, verify, JwtPayload } from 'jsonwebtoken';

@Injectable()
export class AccessTokenService {
  readonly expiresIn = 3600;
  private readonly privateKey: KeyObject;
  private readonly publicKey: KeyObject;
  private readonly issuer: string;
  private readonly audience: string;

  constructor() {
    const path = process.env.JWT_PRIVATE_KEY_PATH;
    const issuer = process.env.JWT_ISSUER;
    const audience = process.env.JWT_AUDIENCE;
    if (!path || !issuer || !audience) {
      throw new Error(
        'JWT_PRIVATE_KEY_PATH, JWT_ISSUER y JWT_AUDIENCE son obligatorios',
      );
    }
    this.privateKey = createPrivateKey(readFileSync(path));
    if (
      this.privateKey.asymmetricKeyType !== 'rsa' ||
      (this.privateKey.asymmetricKeyDetails?.modulusLength ?? 0) < 2048
    ) {
      throw new Error('JWT requiere una clave RSA de al menos 2048 bits');
    }
    this.publicKey = createPublicKey(this.privateKey);
    this.issuer = issuer;
    this.audience = audience;
  }

  issue(user: { id: string; email: string; role: string }): string {
    return sign({ email: user.email, role: user.role }, this.privateKey, {
      algorithm: 'RS256',
      subject: user.id,
      issuer: this.issuer,
      audience: this.audience,
      expiresIn: this.expiresIn,
    });
  }

  verify(token: string): JwtPayload {
    try {
      const claims = verify(token, this.publicKey, {
        algorithms: ['RS256'],
        issuer: this.issuer,
        audience: this.audience,
      });
      if (
        typeof claims === 'string' ||
        typeof claims.sub !== 'string' ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          claims.sub,
        ) ||
        typeof claims.email !== 'string' ||
        !['STUDENT', 'MODERATOR', 'ADMIN'].includes(claims.role as string) ||
        !Number.isInteger(claims.exp) ||
        !Number.isInteger(claims.iat) ||
        claims.mock !== undefined
      ) {
        throw new Error('Claims inválidos');
      }
      return claims;
    } catch {
      throw new UnauthorizedException('Token inválido o expirado');
    }
  }
}
