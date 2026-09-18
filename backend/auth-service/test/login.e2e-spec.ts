import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

describe('Login mock (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue({})
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
  });

  it('devuelve el contrato móvil y un JWT decodificable sin firma ni contraseña', async () => {
    const before = Math.floor(Date.now() / 1000);
    const response = await request(app.getHttpServer() as Server)
      .post('/api/v1/auth/login')
      .send({
        email: 'Estudiante@alu.uct.cl',
        password: 'cualquier-clave',
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
    expect(parts[2]).toBe('');
    expect(JSON.parse(Buffer.from(parts[0], 'base64url').toString())).toEqual({
      alg: 'none',
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
      mock: true,
    });
    expect(payload.iat).toBeGreaterThanOrEqual(before);
    expect(payload.iat).toBeLessThanOrEqual(Math.floor(Date.now() / 1000));
    expect(payload.exp - payload.iat).toBe(body.expiresIn);
    expect(response.text).not.toContain('cualquier-clave');
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
