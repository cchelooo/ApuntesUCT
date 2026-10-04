import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { setupApp } from '../src/setup-app';

describe('Material Service (HTTP)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('expone el healthcheck bajo el prefijo versionado', async () => {
    const response = await request(app.getHttpServer()).get('/api/v1/health').expect(200);
    expect(response.body).toEqual({
      status: 'ok',
      service: 'material-service',
      timestamp: expect.any(String),
    });
    expect(Number.isNaN(Date.parse(response.body.timestamp))).toBe(false);
    await request(app.getHttpServer()).get('/health').expect(404);
  });

  it('publica Swagger y documenta la ruta real del healthcheck', async () => {
    await request(app.getHttpServer()).get('/api/docs/').expect(200).expect('Content-Type', /html/);
    const response = await request(app.getHttpServer()).get('/api/docs-json').expect(200);
    expect(response.body.info.title).toBe('Material Service');
    expect(response.body.paths['/api/v1/health'].get).toBeDefined();
  });
});
