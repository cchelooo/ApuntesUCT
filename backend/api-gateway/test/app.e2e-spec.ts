import { configureRoutes } from '../src/configure-routes';
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import request from 'supertest';
import { AppModule } from './../src/app.module';
import { setupApiDocs } from './../src/api-docs';

describe('API Gateway (e2e)', () => {
  let app: INestApplication;

  // El índice de documentación lee *_DOCS_URL del entorno. Si el equipo tiene
  // alguna de esas variables exportadas (por ejemplo tras una ejecución manual
  // de las pruebas), el HTML mostraría esa URL en lugar del valor por defecto y
  // las aserciones fallarían por un motivo ajeno al código. Se aíslan aquí.
  const DOCS_URL_KEYS = [
    'AUTH_DOCS_URL',
    'CATALOG_DOCS_URL',
    'MATERIAL_DOCS_URL',
    'SEARCH_DOCS_URL',
  ] as const;
  let savedDocsUrls: Record<string, string | undefined>;

  beforeEach(async () => {
    savedDocsUrls = {};
    for (const key of DOCS_URL_KEYS) {
      savedDocsUrls[key] = process.env[key];
      delete process.env[key];
    }

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

  it('/api/docs (GET) lista Material y Search y aclara qué responden hoy (#222)', () => {
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
        // El listado de Material ya está implementado (#318); Search sigue siendo stub.
        expect(res.text).toContain('devuelve el listado paginado de materiales');
        expect(res.text).toContain('la búsqueda sigue siendo un stub');
        expect(res.text).toContain('servicio caído');
        expect(res.text).not.toContain('todavía no expone rutas de materiales');
        expect(res.text).not.toContain('responden 502 hasta que exista');
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
    for (const key of DOCS_URL_KEYS) {
      const saved = savedDocsUrls[key];
      if (saved === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = saved;
      }
    }
  });
});
