import { AccessTokenService } from '../src/infrastructure/security/access-token.service';
import { configureTestJwt } from './jwt-fixture';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { randomUUID } from 'node:crypto';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

process.env.DATABASE_URL =
  process.env.DATABASE_URL ||
  'postgresql://uct_admin:uct_password_123@localhost:5432/auth_db?schema=public';

import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, HttpStatus, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Auth Service - Endpoints HTTP (E2E)', () => {
  let app: INestApplication;

  const mockUser = {
    email: 'auth.test@uct.cl',
    password: 'Password123!',
  };

  let registeredUser: { id: string; email: string; role: string };
  let jwt: ReturnType<typeof configureTestJwt>;
  const userId = randomUUID();
  beforeAll(async () => {
    jwt = configureTestJwt();
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

    // Paso 2/3: Sincronización del prefijo global y pipes de validación con main.ts
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
      }),
    );

    await app.init();
    mockUser.email = `auth-${userId}@uct.cl`;
    const registration = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        name: 'Prueba login',
        ...mockUser,
      })
      .expect(201);
    expect(Object.keys(registration.body)).toEqual(['user']);
    registeredUser = registration.body.user;
    expect(registeredUser).toMatchObject({
      email: mockUser.email,
      role: 'STUDENT',
      active: true,
    });
  });

  afterAll(async () => {
    await app
      .get(PrismaService)
      .user.deleteMany({ where: { email: mockUser.email } });
    await app.close();
    jwt.cleanup();
  });

  // ==========================================
  // INICIO DE SESIÓN (/api/v1/auth/login)
  // ==========================================
  describe('POST /api/v1/auth/login', () => {
    it('debe autenticar correctamente y retornar accessToken/datos (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send(mockUser)
        .expect(HttpStatus.OK);

      const claims = app
        .get(AccessTokenService)
        .verify(response.body.accessToken);
      expect(claims.sub).toBe(registeredUser.id);
      expect(claims.email).toBe(registeredUser.email);
      expect(claims.role).toBe(registeredUser.role);
      expect(response.body.user).toEqual(registeredUser);
      expect(claims).not.toHaveProperty('mock');
      // Verificación acorde al DTO/Swagger actual (accessToken)
      expect(response.body).toHaveProperty('accessToken');
      expect(typeof response.body.accessToken).toBe('string');
      expect(response.body).toHaveProperty('user');
      expect(response.body.user).toHaveProperty(
        'email',
        mockUser.email.toLowerCase(),
      );
    });

    it('rechaza contraseña incorrecta y cuenta inactiva persistida', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ ...mockUser, password: 'incorrecta' })
        .expect(401);
      await app.get(PrismaService).user.update({
        where: { email: mockUser.email },
        data: { active: false },
      });
      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send(mockUser)
        .expect(401);
    });

    it('debe retornar 400 Bad Request si el email es inválido o falta la contraseña', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          email: 'email-invalido',
          password: '   ',
        })
        .expect(HttpStatus.BAD_REQUEST);
    });
  });
});
