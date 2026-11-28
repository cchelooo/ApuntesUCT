import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { generateKeyPairSync } from 'node:crypto';
import { sign } from 'jsonwebtoken';
import {
  AccessTokenVerifier,
  IDENTITY_REQUIRED_MESSAGE,
  extractBearerToken,
} from './access-token.verifier';

const SECRET = 'unit-test-secret-for-hs256-signing';
const AUTHOR_ID = '11111111-1111-4111-8111-111111111111';

function verifier(settings: Record<string, string> = {}): AccessTokenVerifier {
  return new AccessTokenVerifier(new ConfigService(settings));
}

function hsToken(
  overrides: Record<string, unknown> = {},
  options: Record<string, unknown> = {},
): string {
  return sign(
    {
      sub: AUTHOR_ID,
      email: 'estudiante@alu.uct.cl',
      role: 'STUDENT',
      ...overrides,
    },
    SECRET,
    { algorithm: 'HS256', expiresIn: '5m', ...options },
  );
}

function expectUnauthorized(action: () => unknown): void {
  expect(action).toThrow(new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE));
}

describe('AccessTokenVerifier (#446)', () => {
  it('acepta un JWT HS256 firmado y devuelve la identidad del sub', () => {
    expect(verifier({ JWT_ACCESS_SECRET: SECRET }).verify(hsToken())).toEqual({
      id: AUTHOR_ID,
      email: 'estudiante@alu.uct.cl',
      role: 'STUDENT',
    });
  });

  it('valida issuer y audience cuando están configurados', () => {
    const instance = verifier({
      JWT_ACCESS_SECRET: SECRET,
      JWT_ISSUER: 'apuntesuct-auth',
      JWT_AUDIENCE: 'apuntesuct-api',
    });

    expect(
      instance.verify(
        hsToken({}, { issuer: 'apuntesuct-auth', audience: 'apuntesuct-api' }),
      ).id,
    ).toBe(AUTHOR_ID);
    expectUnauthorized(() => instance.verify(hsToken()));
  });

  it.each([
    ['emisor distinto', { iss: 'otro-emisor', aud: 'apuntesuct-api' }],
    ['audiencia distinta', { iss: 'apuntesuct-auth', aud: 'otra-audiencia' }],
  ])('rechaza un token con %s aunque la firma sea válida', (_case, claims) => {
    const instance = verifier({
      JWT_ACCESS_SECRET: SECRET,
      JWT_ISSUER: 'apuntesuct-auth',
      JWT_AUDIENCE: 'apuntesuct-api',
    });

    expectUnauthorized(() => instance.verify(hsToken(claims)));
  });

  it.each([
    [
      'firma con otro secreto',
      () => sign({ sub: AUTHOR_ID, exp: 9999999999 }, 'otro-secreto'),
    ],
    ['token expirado', () => hsToken({}, { expiresIn: -10 })],
    ['alg none', () => noneToken()],
    ['token mock del login temporal', () => hsToken({ mock: true })],
    ['sub que no es UUID', () => hsToken({ sub: 'usuario-1' })],
    [
      'token sin exp',
      () => sign({ sub: AUTHOR_ID }, SECRET, { algorithm: 'HS256' }),
    ],
    ['rol fuera del contrato', () => hsToken({ role: 'SUPERUSER' })],
    ['email con tipo inválido', () => hsToken({ email: 42 })],
  ])('rechaza %s con 401', (_case, build) => {
    expectUnauthorized(() =>
      verifier({ JWT_ACCESS_SECRET: SECRET }).verify(build()),
    );
  });

  it('falla cerrado si no hay clave configurada', () => {
    expectUnauthorized(() => verifier().verify(hsToken()));
  });

  it('no acepta HS256 cuando solo hay clave pública asimétrica', () => {
    const { publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
    const instance = verifier({
      JWT_ACCESS_PUBLIC_KEY: publicKey
        .export({ type: 'spki', format: 'pem' })
        .toString(),
    });

    expectUnauthorized(() => instance.verify(hsToken()));
  });

  it('acepta un JWT RS256 verificado con la clave pública', () => {
    const { privateKey, publicKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    const token = sign(
      { sub: AUTHOR_ID, email: 'docente@uct.cl', role: 'MODERATOR' },
      privateKey.export({ type: 'pkcs8', format: 'pem' }),
      { algorithm: 'RS256', expiresIn: '5m' },
    );
    const instance = verifier({
      JWT_ACCESS_PUBLIC_KEY: publicKey
        .export({ type: 'spki', format: 'pem' })
        .toString(),
    });

    expect(instance.verify(token)).toEqual({
      id: AUTHOR_ID,
      email: 'docente@uct.cl',
      role: 'MODERATOR',
    });
  });
});

describe('AccessTokenVerifier en producción (#446)', () => {
  const PRODUCTION_REQUIRED_MESSAGE =
    'JWT_ISSUER y JWT_AUDIENCE son obligatorios en producción cuando la verificación de identidad está habilitada.';
  const { privateKey, publicKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });
  const publicPem = publicKey
    .export({ type: 'spki', format: 'pem' })
    .toString();
  const privatePem = privateKey
    .export({ type: 'pkcs8', format: 'pem' })
    .toString();

  function rsToken(overrides: Record<string, unknown> = {}): string {
    return sign(
      {
        sub: AUTHOR_ID,
        email: 'docente@uct.cl',
        role: 'MODERATOR',
        ...overrides,
      },
      privatePem,
      { algorithm: 'RS256', expiresIn: '5m' },
    );
  }

  it.each([
    ['solo la clave pública', { JWT_ACCESS_PUBLIC_KEY: publicPem }],
    ['solo el secreto HS256', { JWT_ACCESS_SECRET: SECRET }],
    [
      'clave y emisor sin audiencia',
      { JWT_ACCESS_PUBLIC_KEY: publicPem, JWT_ISSUER: 'apuntesuct-auth' },
    ],
    [
      'clave y audiencia sin emisor',
      { JWT_ACCESS_PUBLIC_KEY: publicPem, JWT_AUDIENCE: 'apuntesuct-api' },
    ],
  ])('no arranca con %s', (_case, settings) => {
    expect(() => verifier({ NODE_ENV: 'production', ...settings })).toThrow(
      PRODUCTION_REQUIRED_MESSAGE,
    );
  });

  it('arranca con la configuración completa y valida emisor y audiencia', () => {
    const instance = verifier({
      NODE_ENV: 'production',
      JWT_ACCESS_PUBLIC_KEY: publicPem,
      JWT_ISSUER: 'apuntesuct-auth',
      JWT_AUDIENCE: 'apuntesuct-api',
    });

    expect(
      instance.verify(
        rsToken({ iss: 'apuntesuct-auth', aud: 'apuntesuct-api' }),
      ).id,
    ).toBe(AUTHOR_ID);
    expectUnauthorized(() =>
      instance.verify(rsToken({ iss: 'otro-emisor', aud: 'apuntesuct-api' })),
    );
    expectUnauthorized(() =>
      instance.verify(
        rsToken({ iss: 'apuntesuct-auth', aud: 'otra-audiencia' }),
      ),
    );
  });

  it('no exige iss/aud en producción si no hay clave de verificación', () => {
    const instance = verifier({ NODE_ENV: 'production' });

    expect(instance.isConfigured()).toBe(false);
    expectUnauthorized(() => instance.verify(hsToken()));
  });
});

describe('extractBearerToken', () => {
  it('extrae el token de un esquema Bearer sin distinguir mayúsculas', () => {
    expect(extractBearerToken('bearer abc.def.ghi')).toBe('abc.def.ghi');
    expect(extractBearerToken('Bearer    abc')).toBe('abc');
  });

  it('devuelve null cuando no hay cabecera', () => {
    expect(extractBearerToken()).toBeNull();
  });

  it.each(['', '   ', 'Basic abc', 'Bearer', 'Bearer a b'])(
    'rechaza la cabecera mal formada %j',
    (header) => {
      expectUnauthorized(() => extractBearerToken(header));
    },
  );
});

function noneToken(): string {
  const header = Buffer.from(
    JSON.stringify({ alg: 'none', typ: 'JWT' }),
  ).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub: AUTHOR_ID, exp: Math.floor(Date.now() / 1000) + 60 }),
  ).toString('base64url');
  return `${header}.${payload}.`;
}
