import { generateKeyPairSync } from 'node:crypto';
import { sign } from 'jsonwebtoken';
import { UnauthorizedException } from '@nestjs/common';
import { configureTestJwt } from '../../../test/jwt-fixture';
import { AccessTokenService } from './access-token.service';

describe('AccessTokenService', () => {
  let fixture: ReturnType<typeof configureTestJwt>;
  let tokens: AccessTokenService;
  const user = {
    id: '00000000-0000-4000-8000-000000000441',
    email: 'user@uct.cl',
    role: 'ADMIN',
  };
  beforeAll(() => {
    fixture = configureTestJwt();
    tokens = new AccessTokenService();
  });
  afterAll(() => fixture.cleanup());

  it('firma identidad y rol con vigencia de una hora', () => {
    const claims = tokens.verify(tokens.issue(user));
    expect(claims).toMatchObject({
      sub: user.id,
      email: user.email,
      role: 'ADMIN',
      iss: 'test-auth',
      aud: 'test-api',
    });
    expect(claims.exp! - claims.iat!).toBe(3600);
    expect(claims).not.toHaveProperty('mock');
  });

  it('rechaza firma ajena, payload alterado, alg none, HS256 y formato inválido', () => {
    const foreign = generateKeyPairSync('rsa', {
      modulusLength: 2048,
    }).privateKey;
    const token = tokens.issue(user);
    const [header, , signature] = token.split('.');
    for (const invalid of [
      sign({ sub: user.id }, foreign, { algorithm: 'RS256' }),
      `${header}.${Buffer.from(JSON.stringify({ sub: user.id, role: 'STUDENT' })).toString('base64url')}.${signature}`,
      sign({ sub: user.id }, null, { algorithm: 'none' }),
      sign(
        { sub: user.id },
        fixture.publicKey.export({ type: 'spki', format: 'pem' }),
        { algorithm: 'HS256' },
      ),
      '',
      'invalid',
    ])
      expect(() => tokens.verify(invalid)).toThrow(UnauthorizedException);
  });

  it.each([
    { exp: 1 },
    { iss: 'other' },
    { aud: 'other' },
    { role: 'OWNER' },
    { sub: 'invalid' },
    { mock: true },
    { exp: undefined },
    { email: undefined },
    { nbf: Math.floor(Date.now() / 1000) + 3600 },
  ])('rechaza claims inválidos %j', (override) => {
    const token = sign(
      JSON.parse(
        JSON.stringify({
          sub: user.id,
          email: user.email,
          role: user.role,
          iss: 'test-auth',
          aud: 'test-api',
          exp: Math.floor(Date.now() / 1000) + 3600,
          ...override,
        }),
      ),
      fixture.privateKey,
      { algorithm: 'RS256' },
    );
    expect(() => tokens.verify(token)).toThrow(UnauthorizedException);
  });

  it('falla sin configuración de clave y no usa secretos predeterminados', () => {
    const path = process.env.JWT_PRIVATE_KEY_PATH;
    delete process.env.JWT_PRIVATE_KEY_PATH;
    try {
      expect(() => new AccessTokenService()).toThrow('JWT_PRIVATE_KEY_PATH');
    } finally {
      process.env.JWT_PRIVATE_KEY_PATH = path;
    }
  });
});
