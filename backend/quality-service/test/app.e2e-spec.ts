import { INestApplication } from '@nestjs/common';
import type { OpenAPIObject } from '@nestjs/swagger';
import { Test } from '@nestjs/testing';
import type { Server } from 'node:http';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { setupApp } from '../src/setup-app';

// Prueba HTTP de la aplicación; la integración real con PostgreSQL está separada.
describe('Quality HTTP', () => {
  let app: INestApplication<Server>;
  const database = {
    $queryRaw: jest.fn<Promise<Array<{ value: number }>>, [TemplateStringsArray]>(),
  };
  let previousUrl: string | undefined;
  let previousPort: string | undefined;

  beforeAll(async () => {
    previousUrl = process.env.DATABASE_URL;
    previousPort = process.env.PORT;
    process.env.DATABASE_URL = 'postgresql://test:test@localhost:5434/quality_db';
    process.env.PORT = '3004';
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue(database)
      .compile();
    app = module.createNestApplication<INestApplication<Server>>();
    setupApp(app);
    await app.init();
  });
  beforeEach(() => database.$queryRaw.mockResolvedValue([{ value: 1 }]));
  afterAll(async () => {
    try {
      if (app) await app.close();
    } finally {
      if (previousUrl === undefined) delete process.env.DATABASE_URL;
      else process.env.DATABASE_URL = previousUrl;
      if (previousPort === undefined) delete process.env.PORT;
      else process.env.PORT = previousPort;
    }
  });
  it('GET /health devuelve 200 y consulta únicamente la base propia', async () => {
    const response = await request(app.getHttpServer()).get('/health').expect(200);
    expect(response.body).toEqual({ status: 'ok', service: 'quality-service', database: 'up' });
    expect(database.$queryRaw).toHaveBeenCalledTimes(1);
    expect(database.$queryRaw.mock.calls[0][0]).toEqual(['SELECT 1']);
  });
  it('devuelve 503 controlado si se pierde la conexión', async () => {
    database.$queryRaw.mockRejectedValueOnce(new Error('private password and hostname'));
    const response = await request(app.getHttpServer()).get('/health').expect(503);
    expect(response.body).toEqual({
      status: 'error',
      service: 'quality-service',
      database: 'down',
    });
    expect(response.text).not.toContain('private');
  });
  it('health no requiere el prefijo global', async () => {
    await request(app.getHttpServer()).get('/api/v1/health').expect(404);
  });
  it('Swagger UI está disponible', async () => {
    await request(app.getHttpServer()).get('/api/docs/').expect(200);
  });
  it('OpenAPI documenta salud y sus respuestas', async () => {
    const response = await request(app.getHttpServer()).get('/api/docs-json').expect(200);
    const document = response.body as OpenAPIObject;
    expect(document.info.title).toBe('Quality Service');
    expect(Object.keys(document.paths['/health'].get?.responses ?? {})).toEqual(
      expect.arrayContaining(['200', '503']),
    );
    expect(database.$queryRaw).not.toHaveBeenCalled();
  });
});
