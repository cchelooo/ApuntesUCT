import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { Server } from 'node:http';
import request from 'supertest';
import { PasswordRecoveryController } from '../src/presentation/auth/password-recovery.controller';
import {
  PasswordRecoveryService,
  RECOVERY_MESSAGE,
} from '../src/application/auth/password-recovery.service';

describe('Recuperación de contraseña (HTTP)', () => {
  let app: INestApplication;
  const recovery = {
    request: jest.fn(() => ({ message: RECOVERY_MESSAGE })),
    reset: jest.fn(() => ({
      message: 'Contraseña restablecida correctamente.',
    })),
  };
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [PasswordRecoveryController],
      providers: [{ provide: PasswordRecoveryService, useValue: recovery }],
    }).compile();
    app = module.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
  });
  beforeEach(() => jest.clearAllMocks());
  afterAll(async () => {
    await app.close();
  });

  it.each([' USER@UCT.CL ', 'missing@example.com'])(
    'solicitud genérica sin secretos: %s',
    async (email) => {
      const response = await request(app.getHttpServer() as Server)
        .post('/api/v1/auth/forgot-password')
        .send({ email })
        .expect(200);
      expect(response.body).toEqual({ message: RECOVERY_MESSAGE });
      expect(response.headers['cache-control']).toBe('no-store');
      expect(recovery.request).toHaveBeenCalledWith(email.trim().toLowerCase());
    },
  );
  it.each([null, 123, '', 'invalid'])(
    'rechaza correo inválido %j',
    async (email) => {
      await request(app.getHttpServer() as Server)
        .post('/api/v1/auth/forgot-password')
        .send({ email })
        .expect(400);
      expect(recovery.request).not.toHaveBeenCalled();
    },
  );
  it.each([
    { token: 'invalid' },
    { token: null },
    { password: 'short' },
    { password: '        ' },
    { password: 'a'.repeat(129) },
    { password: null },
  ])('rechaza reset inválido %j', async (invalid) => {
    await request(app.getHttpServer() as Server)
      .post('/api/v1/auth/reset-password')
      .send({ token: 'a'.repeat(64), password: 'new password', ...invalid })
      .expect(400);
    expect(recovery.reset).not.toHaveBeenCalled();
  });
  it('acepta reset válido sin alterar la contraseña', async () => {
    await request(app.getHttpServer() as Server)
      .post('/api/v1/auth/reset-password')
      .send({
        token: 'a'.repeat(64),
        password: ' new password ',
        userId: 'attacker',
      })
      .expect(200);
    expect(recovery.reset).toHaveBeenCalledWith(
      'a'.repeat(64),
      ' new password ',
    );
  });
});
