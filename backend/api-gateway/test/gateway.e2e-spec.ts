import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, HttpStatus, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import * as http from 'http';
import { AddressInfo } from 'net';
import { AppModule } from '../src/app.module';

describe('API Gateway - Integration & Proxying Tests (E2E)', () => {
  let app: INestApplication;
  let mockDownstreamServer: http.Server;
  let mockServerPort: number;
  let lastCapturedRequest: {
    url?: string;
    headers?: http.IncomingHttpHeaders;
    body?: any;
  } = {};

  const mockValidToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkFudG9uaW8iLCJpYXQiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

  beforeAll(async () => {
    // 1. Crear el servidor HTTP simulado (Downstream Mock)
    mockDownstreamServer = http.createServer((req, res) => {
      const bodyChunks: any[] = [];
      req
        .on('data', (chunk) => bodyChunks.push(chunk))
        .on('end', () => {
          const rawBody = Buffer.concat(bodyChunks).toString();
          lastCapturedRequest = {
            url: req.url,
            headers: req.headers,
            body: rawBody ? JSON.parse(rawBody) : null,
          };

          // Responder 200 OK con el payload capturado o simulado
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(
            JSON.stringify({
              success: true,
              accessToken: 'mock_access_token_jwt',
              data: lastCapturedRequest.body || [],
            }),
          );
        });
    });

    // 2. Iniciar el servidor simulado en puerto dinámico asignado por el SO (listen(0))
    await new Promise<void>((resolve) => {
      mockDownstreamServer.listen(0, '127.0.0.1', () => {
        const address = mockDownstreamServer.address() as AddressInfo;
        mockServerPort = address.port;

        // Sobrescribir variables de entorno antes de compilar el módulo de NestJS
        process.env.AUTH_SERVICE_URL = `http://127.0.0.1:${mockServerPort}`;
        process.env.CATALOG_SERVICE_URL = `http://127.0.0.1:${mockServerPort}`;
        resolve();
      });
    });

    // 3. Compilar el módulo NestJS después de haber asignado las variables de entorno
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
      }),
    );

    await app.init();
  });

  afterAll(async () => {
    if (app) {
      await app.close();
    }
    if (mockDownstreamServer) {
      await new Promise<void>((resolve) => mockDownstreamServer.close(() => resolve()));
    }
  });

  beforeEach(() => {
    lastCapturedRequest = {};
  });

  // ==========================================
  // 1. RUTAS PÚBLICAS Y AUTENTICACIÓN
  // ==========================================
  describe('Authentication & Protected Routes Guard', () => {
    it('POST /api/v1/auth/login - debe permitir acceso público sin pedir Bearer Token y responder 200 OK (Login Simulado)', async () => {
      const loginPayload = {
        email: 'usuario@ejemplo.com',
        password: 'Password123!',
      };

      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send(loginPayload)
        .expect(HttpStatus.OK);

      expect(response.body).toHaveProperty('accessToken');
    });

    it('GET /api/v1/catalog/filter - debe permitir el acceso para consultas públicas de catálogo', async () => {
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
      const loginPayload = {
        email: 'usuario@ejemplo.com',
        password: 'Password123!',
      };

      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .set('Authorization', `Bearer ${mockValidToken}`)
        .set('x-custom-header', 'test-value')
        .send(loginPayload)
        .expect(HttpStatus.OK);

      expect(response.body).toBeDefined();

      // Validación del reenvío capturado en el servidor mock
      expect(lastCapturedRequest.body).toEqual(loginPayload);
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

      expect(lastCapturedRequest.url).toContain('universityId=a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
      expect(lastCapturedRequest.url).toContain('careerId=b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22');
    });

    it('POST /api/v1/catalog/subjects - debe autenticar y reenviar la creación de asignatura al catalog-service', async () => {
      const newSubjectPayload = {
        name: 'Estructura de Datos',
        code: 'INF-201',
        semester: 3,
      };

      const response = await request(app.getHttpServer())
        .post('/api/v1/catalog/subjects')
        .set('Authorization', `Bearer ${mockValidToken}`)
        .send(newSubjectPayload)
        .expect(HttpStatus.OK);

      expect(response.body).toBeDefined();
      expect(lastCapturedRequest.body).toEqual(newSubjectPayload);
      expect(lastCapturedRequest.headers?.['authorization']).toBe(`Bearer ${mockValidToken}`);
    });

    it('DELETE /api/v1/catalog/subjects/:id - debe autenticar y reenviar la eliminación de asignatura al catalog-service', async () => {
      const subjectId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

      await request(app.getHttpServer())
        .delete(`/api/v1/catalog/subjects/${subjectId}`)
        .set('Authorization', `Bearer ${mockValidToken}`)
        .expect(HttpStatus.OK);

      expect(lastCapturedRequest.url).toContain(`/subjects/${subjectId}`);
      expect(lastCapturedRequest.headers?.['authorization']).toBe(`Bearer ${mockValidToken}`);
    });
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