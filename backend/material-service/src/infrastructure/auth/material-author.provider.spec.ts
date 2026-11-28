import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { sign } from 'jsonwebtoken';
import { AccessTokenVerifier, IDENTITY_REQUIRED_MESSAGE } from './access-token.verifier';
import { MaterialAuthorProvider } from './material-author.provider';

const SECRET = 'test-only-jwt-secret-with-enough-entropy';
const AUTHOR_ID = '11111111-1111-4111-8111-111111111111';

function provider(settings: Record<string, string>): MaterialAuthorProvider {
  const config = new ConfigService(settings);
  return new MaterialAuthorProvider(config, new AccessTokenVerifier(config));
}

function token(
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

function noneToken(): string {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub: AUTHOR_ID, exp: Math.floor(Date.now() / 1000) + 60 }),
  ).toString('base64url');
  return `${header}.${payload}.`;
}

describe('MaterialAuthorProvider con identidad real (#446)', () => {
  it('rechaza una identidad firmada sin rol con 403', () => {
    const instance = provider({ JWT_ACCESS_SECRET: SECRET });
    expect(() => instance.resolve('Bearer ' + token({ role: undefined }))).toThrow(
      'Se requiere un rol autorizado.',
    );
  });

  it.each(['STUDENT', 'MODERATOR', 'ADMIN'])('acepta el rol %s para subir', (role) => {
    const instance = provider({ JWT_ACCESS_SECRET: SECRET });
    expect(instance.resolve('Bearer ' + token({ role })).id).toBe(AUTHOR_ID);
  });

  it('usa el sub del token firmado y no el contexto local', () => {
    const instance = provider({
      NODE_ENV: 'development',
      MATERIAL_LOCAL_AUTHOR_ENABLED: 'true',
      MATERIAL_LOCAL_UPLOADER_ID: '99999999-9999-4999-8999-999999999999',
      JWT_ACCESS_SECRET: SECRET,
    });

    expect(instance.resolve(`Bearer ${token()}`)).toEqual({
      id: AUTHOR_ID,
      universityId: null,
    });
  });

  it('rechaza un token con firma inválida sin caer al contexto local', () => {
    const instance = provider({
      NODE_ENV: 'development',
      MATERIAL_LOCAL_AUTHOR_ENABLED: 'true',
      MATERIAL_LOCAL_UPLOADER_ID: AUTHOR_ID,
      JWT_ACCESS_SECRET: SECRET,
    });
    const forged = sign({ sub: AUTHOR_ID, exp: Math.floor(Date.now() / 1000) + 60 }, 'otro');

    expect(() => instance.resolve(`Bearer ${forged}`)).toThrow(
      new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE),
    );
  });

  it.each([
    ['sin firma (alg none)', noneToken()],
    ['mock del login temporal', token({ mock: true })],
  ])('rechaza %s', (_case, value) => {
    const instance = provider({
      NODE_ENV: 'development',
      MATERIAL_LOCAL_AUTHOR_ENABLED: 'true',
      MATERIAL_LOCAL_UPLOADER_ID: AUTHOR_ID,
      JWT_ACCESS_SECRET: SECRET,
    });

    expect(() => instance.resolve(`Bearer ${value}`)).toThrow(
      new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE),
    );
  });

  it('exige identidad si no hay token y el contexto local está deshabilitado', () => {
    const instance = provider({ NODE_ENV: 'development' });

    expect(() => instance.resolve()).toThrow(new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE));
  });

  it('conserva el contexto local explícito solo en development', () => {
    const instance = provider({
      NODE_ENV: 'development',
      MATERIAL_LOCAL_AUTHOR_ENABLED: 'true',
      MATERIAL_LOCAL_UPLOADER_ID: AUTHOR_ID,
    });

    expect(instance.resolve()).toEqual({ id: AUTHOR_ID, universityId: null });
  });

  it.each([
    { NODE_ENV: 'test' },
    { NODE_ENV: '' },
    { MATERIAL_LOCAL_AUTHOR_ENABLED: 'false' },
    { MATERIAL_LOCAL_UPLOADER_ID: '' },
    { MATERIAL_LOCAL_UPLOADER_ID: 'not-a-uuid' },
  ])('no habilita el contexto local con %j', (override) => {
    const instance = provider({
      NODE_ENV: 'development',
      MATERIAL_LOCAL_AUTHOR_ENABLED: 'true',
      MATERIAL_LOCAL_UPLOADER_ID: AUTHOR_ID,
      ...override,
    });

    expect(() => instance.resolve()).toThrow(new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE));
  });

  it('impide habilitar el contexto local en producción', () => {
    expect(() =>
      provider({
        NODE_ENV: 'production',
        MATERIAL_LOCAL_AUTHOR_ENABLED: 'true',
        MATERIAL_LOCAL_UPLOADER_ID: AUTHOR_ID,
      }),
    ).toThrow('MATERIAL_LOCAL_AUTHOR_ENABLED no puede habilitarse con NODE_ENV=production.');
  });

  it('rechaza cabeceras Authorization mal formadas', () => {
    const instance = provider({ NODE_ENV: 'development', JWT_ACCESS_SECRET: SECRET });

    expect(() => instance.resolve('Basic abc')).toThrow(
      new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE),
    );
    expect(() => instance.resolve('Bearer')).toThrow(
      new UnauthorizedException(IDENTITY_REQUIRED_MESSAGE),
    );
  });
});
