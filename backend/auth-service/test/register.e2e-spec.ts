import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Prisma } from '.prisma/auth-client';
import type { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { PasswordHasher } from '../src/infrastructure/security/password-hasher';

describe('Registro institucional (HTTP)', () => {
  let app: INestApplication;
  const create = jest.fn();
  const hash = jest.fn().mockResolvedValue('private-hash');
  const input = {
    name: 'Camila Soto',
    email: 'camila@alu.uct.cl',
    password: ' clave segura ',
  };
  const user = {
    id: '00000000-0000-4000-8000-000000000440',
    name: input.name,
    email: input.email,
    role: 'STUDENT',
    active: true,
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue({ user: { create } })
      .overrideProvider(PasswordHasher)
      .useValue({ hash })
      .compile();
    app = module.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
  });
  beforeEach(() => {
    jest.clearAllMocks();
    create.mockResolvedValue(user);
  });
  afterAll(async () => {
    await app.close();
  });

  it.each(['alu.uct.cl', 'uct.cl'])(
    'normaliza %s y no permite elevar privilegios',
    async (domain) => {
      const response = await request(app.getHttpServer() as Server)
        .post('/api/v1/auth/register')
        .send({
          ...input,
          name: ' Camila Soto ',
          email: ` CAMILA@${domain.toUpperCase()} `,
          role: 'ADMIN',
          active: false,
          passwordHash: 'attacker',
        })
        .expect(201);
      expect(response.body).toEqual({ user });
      expect(hash).toHaveBeenCalledWith(input.password);
      expect(create).toHaveBeenCalledWith({
        data: {
          name: input.name,
          email: `camila@${domain}`,
          passwordHash: 'private-hash',
          role: 'STUDENT',
        },
        select: { id: true, name: true, email: true, role: true, active: true },
      });
      expect(response.text).not.toContain('private-hash');
      expect(response.text).not.toContain(input.password);
    },
  );

  it.each([
    { email: 'a@gmail.com' },
    { email: 'a@sub.uct.cl' },
    { email: 'a@uct.cl.evil.com' },
    { email: 'a@@uct.cl' },
    { email: null },
    { email: 123 },
    { password: 'short' },
    { password: '        ' },
    { password: 'a'.repeat(129) },
    { password: null },
    { password: 123 },
    { name: '  ' },
    { name: null },
    { name: 'a'.repeat(101) },
  ])('rechaza datos inválidos %j antes de persistir', async (invalid) => {
    await request(app.getHttpServer() as Server)
      .post('/api/v1/auth/register')
      .send({ ...input, ...invalid })
      .expect(400);
    expect(create).not.toHaveBeenCalled();
    expect(hash).not.toHaveBeenCalled();
  });

  it('devuelve 409 sin exponer detalles de Prisma', async () => {
    create.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('private-hash', {
        code: 'P2002',
        clientVersion: '6.12.0',
      }),
    );
    const response = await request(app.getHttpServer() as Server)
      .post('/api/v1/auth/register')
      .send(input)
      .expect(409);
    expect(response.body).toMatchObject({
      message: 'El correo ya está registrado',
    });
    expect(response.text).not.toContain('private-hash');
  });
});
