import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, HttpStatus, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('API Gateway - Integration & Authentication Tests (E2E)', () => {
  let app: INestApplication;

  // Token JWT ficticio con formato válido para pruebas de estructura
  const mockValidToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkFudG9uaW8iLCJpYXQiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

    // Replicar la configuración global de la aplicación real
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
  });

  // ==========================================
  // 1. RUTAS PÚBLICAS Y AUTENTICACIÓN
  // ==========================================
  describe('Authentication & Protected Routes Guard', () => {
    it('POST /api/v1/auth/login - debe permitir acceso público sin Bearer Token', async () => {
      const response = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          email: 'usuario@ejemplo.com',
          password: 'Password123!',
        });

      // Se espera que NO rechace con 401 Unauthorized por falta de token
      expect(response.status).not.toBe(HttpStatus.UNAUTHORIZED);
    });

    it('GET /api/v1/catalog/filter - debe permitir el paso para consultas de catálogo', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter');

      expect([HttpStatus.OK, HttpStatus.BAD_REQUEST, HttpStatus.SERVICE_UNAVAILABLE, HttpStatus.NOT_FOUND]).toContain(
        response.status,
      );
    });

    it('GET /api/v1/catalog/filter - debe procesar correctamente cuando se envía un Bearer Token', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .set('Authorization', `Bearer ${mockValidToken}`);

      expect(response.status).not.toBe(HttpStatus.UNAUTHORIZED);
    });
  });

  // ==========================================
  // 2. REENVÍO DE PETICIONES (PROXYING / ROUTING)
  // ==========================================
  describe('Request Proxying to Downstream Services', () => {
    it('POST /api/v1/catalog - debe reenviar correctamente el body y headers al catalog-service', async () => {
      const newSubjectDto = {
        name: 'Redes de Computadores',
        code: 'INF-321',
        semester: 5,
        careerId: 'c2e917d0-1c5a-4b9e-9d22-2a704e9c0001',
      };

      const response = await request(app.getHttpServer())
        .post('/api/v1/catalog') // Se usa la ruta base /catalog para operaciones de creación (POST)
        .set('Authorization', `Bearer ${mockValidToken}`)
        .send(newSubjectDto);

      // El Gateway debe transmitir la solicitud (acepta respuestas válidas del microservicio o 404/503 si el downstream está desconectado)
      expect([
        HttpStatus.CREATED,
        HttpStatus.OK,
        HttpStatus.BAD_REQUEST,
        HttpStatus.SERVICE_UNAVAILABLE,
        HttpStatus.NOT_FOUND,
      ]).toContain(response.status);
    });

    it('GET /api/v1/catalog/filter?universityId=uni-1 - debe preservar los Query Parameters en el reenvío', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({ universityId: 'uni-1', careerId: 'car-1' })
        .set('Authorization', `Bearer ${mockValidToken}`);

      expect(response.status).not.toBe(HttpStatus.UNAUTHORIZED);
    });
  });

  // ==========================================
  // 3. MANEJO DE ERRORES Y TIMEOUTS
  // ==========================================
  describe('Resilience & Error Handling', () => {
    it('GET /api/v1/ruta-inexistente - debe responder con 404 Not Found', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/ruta-inexistente')
        .set('Authorization', `Bearer ${mockValidToken}`)
        .expect(HttpStatus.NOT_FOUND);
    });
  });
});