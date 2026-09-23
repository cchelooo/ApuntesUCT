import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, HttpStatus, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Catalog Service - Endpoints HTTP (E2E)', () => {
  let app: INestApplication;

  jest.setTimeout(30000);

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

    // Si tu main.ts usa setGlobalPrefix, descomenta la siguiente línea:
    // app.setGlobalPrefix('api');

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
  // 1. ÁRBOL DEL CATÁLOGO (GET /catalog)
  // ==========================================
  describe('GET /catalog', () => {
    it('debe obtener la estructura jerárquica del catálogo (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/catalog')
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  // ==========================================
  // 2. FILTRADO DEL CATÁLOGO (GET /catalog/filter)
  // ==========================================
  describe('GET /catalog/filter', () => {
    it('debe retornar resultados al consultar sin query params (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/catalog/filter')
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('debe retornar 400 Bad Request si la secuencia jerárquica de filtros es inválida', async () => {
      // Filtrar por careerId sin universityId rompe la regla de la secuencia jerárquica
      await request(app.getHttpServer())
        .get('/catalog/filter')
        .query({ careerId: '00000000-0000-0000-0000-000000000001' })
        .expect(HttpStatus.BAD_REQUEST);
    });

    it('debe gestionar el envío del filtro year (Nivel 5)', async () => {
      const response = await request(app.getHttpServer())
        .get('/catalog/filter')
        .query({
          universityId: '00000000-0000-0000-0000-000000000001',
          careerId: '00000000-0000-0000-0000-000000000002',
          subjectId: '00000000-0000-0000-0000-000000000003',
          professorId: '00000000-0000-0000-0000-000000000004',
          year: 2026,
        });

      expect([HttpStatus.NOT_IMPLEMENTED, HttpStatus.BAD_REQUEST]).toContain(response.status);
    });
  });
});