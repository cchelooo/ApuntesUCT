import { configureTestJwt } from './jwt-fixture';
import { PasswordHasher } from '../src/infrastructure/security/password-hasher';
import { AccessTokenService } from '../src/infrastructure/security/access-token.service';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

describe('Login real (e2e)', () => {
  let app: INestApplication;
  let jwt: ReturnType<typeof configureTestJwt>;
  const findUnique = jest.fn();
  const user = {
    id: '00000000-0000-4000-8000-000000000441',
    name: 'Estudiante de prueba',
    email: 'estudiante@alu.uct.cl',
    role: 'STUDENT',
    active: true,
    passwordHash: '',
  };
  beforeEach(() => findUnique.mockResolvedValue(user));

  beforeAll(async () => {
    jwt = configureTestJwt();
    user.passwordHash = await new PasswordHasher().hash(' demo con espacios ');
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue({ user: { findUnique } })
      .compile();
    app = module.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
    jwt.cleanup();
  });

  it('devuelve el contrato móvil y un JWT verificable ni contraseña', async () => {
    const before = Math.floor(Date.now() / 1000);
    const response = await request(app.getHttpServer() as Server)
      .post('/api/v1/auth/login')
      .send({
        email: 'Estudiante@alu.uct.cl',
        password: ' demo con espacios ',
        role: 'ADMIN',
      })
      .expect(200);
    const body = response.body as {
      accessToken: string;
      tokenType: string;
      expiresIn: number;
      user: {
        id: string;
        name: string;
        email: string;
        role: string;
        active: boolean;
      };
    };
    expect(body).toEqual({
      accessToken: expect.any(String),
      tokenType: 'Bearer',
      expiresIn: 3600,
      user: {
        id: expect.any(String),
        name: 'Estudiante de prueba',
        email: 'estudiante@alu.uct.cl',
        role: 'STUDENT',
        active: true,
      },
    });
    const parts = body.accessToken.split('.');
    expect(parts).toHaveLength(3);
    expect(parts[2]).not.toBe('');
    expect(app.get(AccessTokenService).verify(body.accessToken).sub).toBe(
      user.id,
    );
    expect(JSON.parse(Buffer.from(parts[0], 'base64url').toString())).toEqual({
      alg: 'RS256',
      typ: 'JWT',
    });
    const payload = JSON.parse(
      Buffer.from(parts[1], 'base64url').toString(),
    ) as { iat: number; exp: number };
    expect(payload).toEqual({
      sub: body.user.id,
      email: body.user.email,
      role: 'STUDENT',
      iat: expect.any(Number),
      exp: expect.any(Number),
      iss: 'test-auth',
      aud: 'test-api',
    });
    expect(payload.iat).toBeGreaterThanOrEqual(before);
    expect(payload.iat).toBeLessThanOrEqual(Math.floor(Date.now() / 1000));
    expect(payload.exp - payload.iat).toBe(body.expiresIn);
    expect(response.text).not.toContain(' demo con espacios ');
  });

  it.each(['MODERATOR', 'ADMIN'])(
    'conserva el rol persistido %s',
    async (role) => {
      findUnique.mockResolvedValue({ ...user, role });
      const response = await request(app.getHttpServer() as Server)
        .post('/api/v1/auth/login')
        .send({
          email: user.email,
          password: ' demo con espacios ',
          role: 'STUDENT',
        })
        .expect(200);
      expect(response.body.user.role).toBe(role);
      expect(
        app.get(AccessTokenService).verify(response.body.accessToken).role,
      ).toBe(role);
    },
  );

  it.each(['incorrecta', 'desconocido', 'inactivo'])(
    'rechaza %s con 401',
    async (scenario) => {
      if (scenario === 'desconocido') findUnique.mockResolvedValue(null);
      if (scenario === 'inactivo')
        findUnique.mockResolvedValue({ ...user, active: false });
      const response = await request(app.getHttpServer() as Server)
        .post('/api/v1/auth/login')
        .send({
          email: user.email,
          password:
            scenario === 'incorrecta' ? 'incorrecta' : ' demo con espacios ',
        })
        .expect(401);
      expect(response.body.message).toBe('Credenciales inválidas');
    },
  );

  it.each(['   ', '\t', '\n', ' \t\r\n ', '\u00a0'])(
    'rechaza una contraseña formada solo por espacios en blanco: %j',
    async (password) => {
      await request(app.getHttpServer() as Server)
        .post('/api/v1/auth/login')
        .send({ email: 'estudiante@alu.uct.cl', password })
        .expect(400);
    },
  );

  it('acepta una contraseña con espacios y otros caracteres', async () => {
    await request(app.getHttpServer() as Server)
      .post('/api/v1/auth/login')
      .send({ email: 'estudiante@alu.uct.cl', password: ' demo con espacios ' })
      .expect(200);
  });

  it.each([
    {},
    { email: 'estudiante@alu.uct.cl' },
    { password: 'demo' },
    { email: 'invalido', password: 'demo' },
    { email: 'estudiante@alu.uct.cl', password: '' },
    { email: 'estudiante@alu.uct.cl', password: 123 },
    { email: null, password: 'demo' },
  ])('rechaza un cuerpo inválido: %j', async (body) => {
    await request(app.getHttpServer() as Server)
      .post('/api/v1/auth/login')
      .send(body)
      .expect(400);
  });
});
