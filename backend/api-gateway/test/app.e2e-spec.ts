import { configureRoutes } from '../src/configure-routes';
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
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
    configureRoutes(app);
    setupApiDocs(app, app.get(ConfigService));
    await app.init();
  });

  it.each(['/health', '/api/v1/health'])(
    '%s (GET) responde sin autenticación con el estado actual del Gateway',
    async (path) => {
      const beforeRequest = Date.now();
      const response = await request(app.getHttpServer())
        .get(path)
        .expect(200)
        .expect('Content-Type', /application\/json/)
        .expect('Cache-Control', 'no-store');

      expect(response.body).toEqual({
        status: 'ok',
        service: 'API Gateway',
        timestamp: expect.any(String),
      });
      const timestamp = Date.parse(response.body.timestamp);
      expect(timestamp).toBeGreaterThanOrEqual(beforeRequest);
      expect(timestamp).toBeLessThanOrEqual(Date.now());
      expect(new Date(timestamp).toISOString()).toBe(response.body.timestamp);
    },
  );

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

  it('/api/docs (GET) lista Material y Search y aclara que aún no existen (#222)', () => {
    return request(app.getHttpServer())
      .get('/api/docs')
      .expect(200)
      .expect('Content-Type', /text\/html/)
      .expect((res) => {
        expect(res.text).toContain('Material Service');
        expect(res.text).toContain('Search Service');
        expect(res.text).toContain('http://localhost:3003/api/docs');
        expect(res.text).toContain('http://localhost:3005/api/docs');
        expect(res.text).toContain('Quality Service todavía no está enrutado');
        expect(res.text).toContain('502');
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
        for (const path of ['/health', '/api/v1/health']) {
          expect(res.body.paths[path].get.responses['200']).toBeDefined();
        }
        expect(res.body.paths['/api/v1/api/v1/health']).toBeUndefined();
      });
  });

  it('/api/docs (GET) respeta las URLs configuradas por entorno', async () => {
    process.env.AUTH_DOCS_URL = 'http://doc-auth.internal/api/docs';
    process.env.CATALOG_DOCS_URL = 'http://doc-catalog.internal/api/docs';
    process.env.MATERIAL_DOCS_URL = 'http://doc-material.internal/api/docs';
    process.env.SEARCH_DOCS_URL = 'http://doc-search.internal/api/docs';

    const configuredModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    const configuredApp = configuredModule.createNestApplication();
    configureRoutes(configuredApp);
    setupApiDocs(configuredApp, configuredApp.get(ConfigService));
    await configuredApp.init();

    try {
      const res = await request(configuredApp.getHttpServer())
        .get('/api/docs')
        .expect(200);
      expect(res.text).toContain('http://doc-auth.internal/api/docs');
      expect(res.text).toContain('http://doc-catalog.internal/api/docs');
      expect(res.text).toContain('http://doc-material.internal/api/docs');
      expect(res.text).toContain('http://doc-search.internal/api/docs');
      expect(res.text).not.toContain('http://localhost:3001/api/docs');
      expect(res.text).not.toContain('http://localhost:3002/api/docs');
      expect(res.text).not.toContain('http://localhost:3003/api/docs');
      expect(res.text).not.toContain('http://localhost:3005/api/docs');
    } finally {
      await configuredApp.close();
      delete process.env.AUTH_DOCS_URL;
      delete process.env.CATALOG_DOCS_URL;
      delete process.env.MATERIAL_DOCS_URL;
      delete process.env.SEARCH_DOCS_URL;
    }
  });

  afterEach(async () => {
    await app.close();
  });
});
