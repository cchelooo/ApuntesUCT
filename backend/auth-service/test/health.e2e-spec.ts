import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import type { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from './../src/app.module';
import { PrismaService } from './../src/infrastructure/prisma/prisma.service';

async function createApp(
  prisma: Partial<PrismaService>,
): Promise<INestApplication> {
  const moduleFixture: TestingModule = await Test.createTestingModule({
    imports: [AppModule],
  })
    .overrideProvider(PrismaService)
    .useValue(prisma)
    .compile();

  const app = moduleFixture.createNestApplication();
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, transform: true }),
  );
  await app.init();
  return app;
}

describe('Auth Service (e2e)', () => {
  it('/api/v1/health (GET) devuelve 200 cuando PostgreSQL responde', async () => {
    const app = await createApp({
      $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
    });
    try {
      const httpServer = app.getHttpServer() as Server;
      const res = await request(httpServer).get('/api/v1/health').expect(200);

      expect(res.body.status).toBe('ok');
      expect(res.body.service).toBe('auth-service');
      expect(res.body.database).toBe('connected');
      expect(res.body.timestamp).toEqual(expect.any(String));
    } finally {
      await app.close();
    }
  });

  it('/api/v1/health (GET) devuelve 503 cuando PostgreSQL no responde', async () => {
    const app = await createApp({
      $queryRaw: jest
        .fn()
        .mockRejectedValue(new Error('sin conexión a la base de datos')),
    });
    try {
      const httpServer = app.getHttpServer() as Server;
      const res = await request(httpServer).get('/api/v1/health').expect(503);

      expect(res.body.status).toBe('unavailable');
      expect(res.body.service).toBe('auth-service');
      expect(res.body.database).toBe('disconnected');
      expect(res.body.timestamp).toEqual(expect.any(String));
    } finally {
      await app.close();
    }
  });
});