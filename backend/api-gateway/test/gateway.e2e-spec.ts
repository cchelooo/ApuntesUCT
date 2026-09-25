import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, HttpStatus, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import * as http from 'http';

// 1. Inyectar variables de entorno ANTES de importar AppModule 
// para forzar que el Gateway reenvíe sus peticiones al mock server (puerto 9999)
process.env.AUTH_SERVICE_URL = 'http://127.0.0.1:9999';
process.env.CATALOG_SERVICE_URL = 'http://127.0.0.1:9999';

import { AppModule } from '../src/app.module';

describe('API Gateway - Integration & Proxying Tests (E2E)', () => {
  let app: INestApplication;
  let mockDownstreamServer: http.Server;
  let lastCapturedRequest: {
    url?: string;
    headers?: http.IncomingHttpHeaders;
    body?: any;
  } = {};

  const mockValidToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkFudG9uaW8iLCJpYXQiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

  beforeAll(async () => {
    // 2. Servidor Mock que responderá por los microservicios
    mockDownstreamServer = http.createServer((req, res) => {
      let bodyChunks: any[] = [];
      req
        .on('data', (chunk) => bodyChunks.push(chunk))
        .on('end', () => {
          const rawBody = Buffer.concat(bodyChunks).toString();
          lastCapturedRequest = {
            url: req.url,
            headers: req.headers,
            body: rawBody ? JSON.parse(rawBody) : null,
          };

          // Responder OK a cualquier ruta (catalog/filter, auth/test-proxy, etc.)
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(
            JSON.stringify({
              success: true,
              data: lastCapturedRequest.body || [],
            }),
          );
        });
    });

    await new Promise<void>((resolve) => mockDownstreamServer.listen(9999, '127.0.0.1', resolve));

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

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
    await new Promise<void>((resolve) => mockDownstreamServer.close(() => resolve()));
  });

  beforeEach(() => {
    lastCapturedRequest = {};
  });

  // ==========================================
  // 1. RUTAS PÚBLICAS Y AUTENTICACIÓN
  // ==========================================
  describe('Authentication & Protected Routes Guard', () => {
    it('POST /api/v1/auth/login - debe permitir acceso público sin exigir Bearer Token', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          email: 'usuario@ejemplo.com',
          password: 'Password123!',
        });

      expect(response.status).not.toBe(HttpStatus.UNAUTHORIZED);
    });

    it('GET /api/v1/catalog/filter - debe permitir el acceso para consultas de catálogo', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({ universityId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' })
        .expect(HttpStatus.OK);

      expect(response.body).toBeDefined();
    });
  });

  // ==========================================
  // 2. REENVÍO DE PETICIONES (PROXYING / ROUTING)
  // ==========================================
  describe('Reenvío de peticiones (Body, Headers, Query Params)', () => {
    it('debe reenviar correctamente el Body, Headers y Token al servicio destino', async () => {
      const payloadDto = {
        name: 'Estructuras de Datos',
        code: 'INF-210',
      };

      // Nota: Utiliza un endpoint proxy real configurado en tu Gateway (ej: /api/v1/auth/login o /api/v1/catalog/filter)
      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .set('Authorization', `Bearer ${mockValidToken}`)
        .set('x-custom-header', 'test-value')
        .send({
          email: 'usuario@ejemplo.com',
          password: 'Password123!',
        });

      expect(response.status).toBe(HttpStatus.OK);
      expect(lastCapturedRequest.headers?.['authorization']).toBe(`Bearer ${mockValidToken}`);
      expect(lastCapturedRequest.headers?.['x-custom-header']).toBe('test-value');
    });

    it('GET /api/v1/catalog/filter - debe preservar los Query Parameters en el reenvío', async () => {
      const queryParams = {
        universityId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        careerId: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
      };

      await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query(queryParams)
        .set('Authorization', `Bearer ${mockValidToken}`)
        .expect(HttpStatus.OK);

      // Verificar que el downstream server recibió los query params en la URL
      expect(lastCapturedRequest.url).toContain('universityId=a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
      expect(lastCapturedRequest.url).toContain('careerId=b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22');
    });

    it.todo('POST /api/v1/catalog - debe reenviar la creación de asignatura al catalog-service cuando el proxy esté implementado');
    it.todo('DELETE /api/v1/catalog/subjects/:id - debe reenviar la eliminación de asignatura');
  });

  // ==========================================
  // 3. MANEJO DE ERRORES Y RUTAS INEXISTENTES
  // ==========================================
  describe('Resilience & Error Handling', () => {
    it('GET /api/v1/ruta-inexistente - debe responder exactamente con 404 Not Found', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/ruta-inexistente')
        .set('Authorization', `Bearer ${mockValidToken}`)
        .expect(HttpStatus.NOT_FOUND);
    });
  });
});