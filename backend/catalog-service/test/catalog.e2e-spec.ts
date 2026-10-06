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

    it('debe ignorar year/type de clientes heredados sobre una jerarquía válida (200 OK)', async () => {
      // Catalog ya no filtra por año/tipo: esos metadatos pertenecen a Material
      // y la búsqueda por año/tipo a Search. Con `whitelist` los parámetros
      // desconocidos se descartan y la petición sigue siendo válida.
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({
          universityId: validUUIDs.universityId,
          careerId: validUUIDs.careerId,
          subjectId: validUUIDs.subjectId,
          professorId: validUUIDs.professorId,
          year: 2026,
          type: 'APUNTE',
        })
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  // ==========================================
  // 3. LISTADOS PARA SELECTORES ACADÉMICOS
  // ==========================================
  describe('GET /api/v1/catalog/universities', () => {
    it('debe listar las universidades activas (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/universities')
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });
  });

  describe('GET /api/v1/catalog/careers', () => {
    it('debe listar carreras activas sin filtro (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/careers')
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('debe aceptar el filtro universityId (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/careers')
        .query({ universityId: validUUIDs.universityId })
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('debe retornar 400 Bad Request si universityId no es un UUID', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/catalog/careers')
        .query({ universityId: 'no-es-uuid' })
        .expect(HttpStatus.BAD_REQUEST);
    });
  });

  describe('GET /api/v1/catalog/subjects', () => {
    it('debe listar asignaturas activas sin filtro (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/subjects')
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('debe aceptar el filtro careerId (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/subjects')
        .query({ careerId: validUUIDs.careerId })
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('debe retornar 400 Bad Request si careerId no es un UUID', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/catalog/subjects')
        .query({ careerId: 'no-es-uuid' })
        .expect(HttpStatus.BAD_REQUEST);
    });
  });

  describe('GET /api/v1/catalog/professors', () => {
    it('debe listar profesores activos sin filtro (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/professors')
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('debe aceptar el filtro subjectId (200 OK)', async () => {
      const response = await request(app.getHttpServer())
        .get('/api/v1/catalog/professors')
        .query({ subjectId: validUUIDs.subjectId })
        .expect(HttpStatus.OK);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('debe retornar 400 Bad Request si subjectId no es un UUID', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/catalog/professors')
        .query({ subjectId: 'no-es-uuid' })
        .expect(HttpStatus.BAD_REQUEST);
    });
  });

  // ==========================================
  // 4. GESTIÓN DEL CATÁLOGO
  // ==========================================
  describe('POST /api/v1/catalog/universities', () => {
    it('debe retornar 404 Not Found si la carrera apunta a una universidad inexistente', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/catalog/careers')
        .send({
          universityId: validUUIDs.universityId,
          name: 'Carrera huérfana',
          code: 'HUE-001',
        })
        .expect(HttpStatus.NOT_FOUND);
    });
  });

  describe('DELETE /api/v1/catalog/:recurso/:id', () => {
    it.each([
      ['universities', 'Universidad'],
      ['careers', 'Carrera'],
      ['professors', 'Profesor'],
      ['subjects', 'Asignatura'],
    ])(
      'debe retornar 404 Not Found al eliminar %s inexistente',
      async (recurso: string) => {
        await request(app.getHttpServer())
          .delete(`/api/v1/catalog/${recurso}/${validUUIDs.universityId}`)
          .expect(HttpStatus.NOT_FOUND);
      },
    );
  });
});