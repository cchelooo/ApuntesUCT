import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Catalog Service - Regresión Post-Separación de Dominios (e2e)', () => {
  let app: INestApplication;

  const missingId = '00000000-0000-4000-8000-000000000001';

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();

    // Configuración idéntica a main.ts para respetar prefijos y validaciones
    app.setGlobalPrefix('api/v1', { exclude: ['health'] });
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  // =========================================================================
  // CRITERIO 1: Árbol académico continúa operativo
  // =========================================================================
  describe('Criterio 1: Árbol Académico', () => {
    it('GET /api/v1/catalog - debe retornar la jerarquía completa del catálogo (200)', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog')
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
    });
  });

  // =========================================================================
  // CRITERIO 2: Filtros hasta Profesor funcionan
  // =========================================================================
  describe('Criterio 2: Filtros Jerárquicos hasta Profesor', () => {
    it('permite consultas sin filtros o con parámetros válidos (200)', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
    });

    it('rechaza con HTTP 400 si se rompe la secuencia obligatoria (ej: careerId sin universityId)', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({ careerId: missingId })
        .expect(400);
    });

    it('ignora de forma segura parámetros heredados de Material/Search (year, type) manteniendo compatibilidad', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({ year: 2026, type: 'APUNTE' })
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
    });
  });

  // =========================================================================
  // CRITERIO 3: Endpoints individuales funcionan
  // =========================================================================
  describe('Criterio 3: Endpoints Individuales y Selectores', () => {
    it('GET /api/v1/catalog/universities - lista universidades activas (200)', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/universities')
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
    });

    it('GET /api/v1/catalog/careers - lista carreras, permitiendo filtro opcional por universityId (200)', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/careers')
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
    });

    it('GET /api/v1/catalog/subjects - lista asignaturas con soporte para careerId (200)', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/subjects')
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
    });

    it('GET /api/v1/catalog/professors - lista profesores con soporte para subjectId (200)', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/professors')
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
    });
  });

  // =========================================================================
  // CRITERIO 4: Dominio y Errores
  // =========================================================================
  describe('Criterio 4: Integridad del Dominio y Errores', () => {
    it('responde 404 al intentar operar sobre registros dependientes inexistentes', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/catalog/careers')
        .send({
          universityId: missingId,
          name: 'Carrera Test',
          code: 'TST-01',
        })
        .expect(404);
    });
  });
});