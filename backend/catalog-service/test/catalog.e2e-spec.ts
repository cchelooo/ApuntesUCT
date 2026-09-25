import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, HttpStatus, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Catalog Service - Endpoints HTTP (E2E)', () => {
  let app: INestApplication;

  // UUIDs formato v4 válidos para superar la validación del ValidationPipe
  const validUUIDs = {
    universityId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    careerId: 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
    subjectId: 'c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
    professorId: 'd3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44',
  };

  jest.setTimeout(30000);

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

    // Sincronización del prefijo global y pipes de validación exactamente como en main.ts
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
  // 1. ÁRBOL DEL CATÁLOGO (GET /api/v1/catalog)
  // ==========================================
  describe('GET /api/v1/catalog', () => {
    it('debe obtener la estructura jerárquica del catálogo (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog')
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  // ==========================================
  // 2. FILTRADO DEL CATÁLOGO (GET /api/v1/catalog/filter)
  // ==========================================
  describe('GET /api/v1/catalog/filter', () => {
    it('debe retornar resultados al consultar sin query params (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('debe retornar 400 Bad Request si la secuencia jerárquica de filtros es inválida', async () => {
      // Filtrar por careerId sin universityId viola la regla de la secuencia jerárquica
      await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({ careerId: validUUIDs.careerId })
        .expect(HttpStatus.BAD_REQUEST);
    });

    it('debe retornar 501 Not Implemented al solicitar el filtro year (Nivel 5) sobre jerarquía válida', async () => {
      // Petición con secuencia jerárquica completa + nivel no implementado (year)
      await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({
          universityId: validUUIDs.universityId,
          careerId: validUUIDs.careerId,
          subjectId: validUUIDs.subjectId,
          professorId: validUUIDs.professorId,
          year: 2026,
        })
        .expect(HttpStatus.NOT_IMPLEMENTED); // Aserción estricta de estado 501 exigida por el revisor
    });
  });
});