import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import type { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from './../src/app.module';

describe('Catalog Service - Health Check (e2e)', () => {
  let app: INestApplication;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

    // Sincronización con main.ts: Excluir 'health' del prefijo global /api/v1
    app.setGlobalPrefix('api/v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
  });

  afterEach(async () => {
    await app.close();
  });

  it('/health (GET) - debe responder con HTTP 200 y los campos status, service y timestamp', () => {
    const httpServer = app.getHttpServer() as Server;
    return request(httpServer)
      .get('/health')
      .expect(200)
      .expect((res) => {
        const body = res.body as {
          status: string;
          service: string;
          timestamp: string;
        };

        expect(body.status).toBe('ok');
        expect(body.service).toBe('catalog-service');
        expect(body.timestamp).toBeDefined();
        expect(typeof body.timestamp).toBe('string');
      });
  });
});