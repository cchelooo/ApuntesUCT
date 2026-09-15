import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from './../src/app.module';
import { setupApiDocs } from './../src/api-docs';

describe('API Gateway (e2e)', () => {
  let app: INestApplication;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    setupApiDocs(app);
    await app.init();
  });

  it('/api/v1/health (GET)', () => {
    return request(app.getHttpServer())
      .get('/api/v1/health')
      .expect(200)
      .expect((res) => {
        expect(res.body.status).toEqual('ok');
        expect(res.body.service).toEqual('API Gateway');
      });
  });

  it('/api/docs (GET) expone el índice de documentación', () => {
    return request(app.getHttpServer())
      .get('/api/docs')
      .expect(200)
      .expect('Content-Type', /text\/html/)
      .expect((res) => {
        expect(res.text).toContain('API Gateway — Documentación');
        expect(res.text).toContain('http://localhost:3001/api/docs');
        expect(res.text).toContain('http://localhost:3002/api/docs');
      });
  });

  it('/api/docs/gateway (GET) expone el Swagger del gateway', () => {
    return request(app.getHttpServer())
      .get('/api/docs/gateway')
      .expect(200)
      .expect('Content-Type', /text\/html/);
  });

  it('/api/docs/gateway-json (GET) expone la especificación OpenAPI', () => {
    return request(app.getHttpServer())
      .get('/api/docs/gateway-json')
      .expect(200)
      .expect('Content-Type', /application\/json/)
      .expect((res) => {
        expect(res.body.info.title).toEqual('API Gateway');
      });
  });

  afterAll(async () => {
    await app.close();
  });
});
