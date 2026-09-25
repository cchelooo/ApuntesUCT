import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

process.env.DATABASE_URL = 
  process.env.DATABASE_URL ||
  "postgresql://uct_admin:uct_password_123@localhost:5432/auth_db?schema=public";

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

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

    // Paso 2/3: Sincronización del prefijo global y pipes de validación con main.ts
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );

    await app.init();
  });

  afterAll(async () => {
    await app.close();
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

      // Verificación acorde al DTO/Swagger actual (accessToken)
      expect(response.body).toHaveProperty('accessToken');
      expect(typeof response.body.accessToken).toBe('string');
      expect(response.body).toHaveProperty('user');
      expect(response.body.user).toHaveProperty('email', mockUser.email.toLowerCase());
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