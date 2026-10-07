import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { randomUUID } from 'node:crypto';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

describe('Catalog Service (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  // UUIDs válidos que no existen en la base: sirven para comprobar el filtro
  // vacío y la validación de formato.
  const missing = {
    universityId: '00000000-0000-4000-8000-000000000001',
    careerId: '00000000-0000-4000-8000-000000000002',
    subjectId: '00000000-0000-4000-8000-000000000003',
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();

    // Mismo prefijo y pipes que src/main.ts
    app.setGlobalPrefix('api/v1', { exclude: ['health'] });
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  // =========================================================================
  // GET /api/v1/catalog
  // =========================================================================
  describe('GET /api/v1/catalog', () => {
    it('devuelve el árbol jerárquico como arreglo (200)', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog')
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
    });
  });

  // =========================================================================
  // GET /api/v1/catalog/filter
  // =========================================================================
  describe('GET /api/v1/catalog/filter', () => {
    it('acepta la petición sin filtros (200)', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
    });

    it('rechaza una secuencia jerárquica inválida (400)', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({ careerId: missing.careerId })
        .expect(400);
    });

    it('ignora year/type heredados sobre una jerarquía válida (200)', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({
          universityId: missing.universityId,
          year: 2026,
          type: 'APUNTE',
        })
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
    });
  });

  // =========================================================================
  // GESTIÓN DEL CATÁLOGO
  // =========================================================================
  describe('Gestión del catálogo', () => {
    it('responde 404 al crear una carrera con universidad inexistente', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/catalog/careers')
        .send({
          universityId: missing.universityId,
          name: 'Carrera huérfana',
          code: 'HUE-001',
        })
        .expect(404);
    });

    it.each(['universities', 'careers', 'professors', 'subjects'])(
      'responde 404 al eliminar %s inexistente',
      async (recurso: string) => {
        await request(app.getHttpServer())
          .delete(`/api/v1/catalog/${recurso}/${missing.universityId}`)
          .expect(404);
      },
    );
  });

  // =========================================================================
  // LISTADOS PARA SELECTORES ACADÉMICOS (datos controlados)
  //
  // Se siembra una jerarquía aislada por ejecución (sufijo aleatorio) para no
  // depender de los datos existentes: dos universidades activas, una inactiva,
  // carreras y asignaturas activas/inactivas y profesores activo/inactivo
  // vinculados a distintas asignaturas.
  // =========================================================================
  describe('GET /api/v1/catalog/<selectores>', () => {
    const run = randomUUID().slice(0, 8);
    const email = (suffix: string) => `e2e-${run}-${suffix}@uct.cl`;

    const ids = {
      universityA: '',
      universityB: '',
      universityInactive: '',
      careerA: '',
      careerAInactive: '',
      careerB: '',
      subjectA: '',
      subjectAInactive: '',
      subjectB: '',
      professorA: '',
      professorAInactive: '',
      professorB: '',
    };

    beforeAll(async () => {
      const universityA = await prisma.university.create({
        data: { name: `E2E Uni A ${run}`, code: `E2E-UA-${run}`, active: true },
      });
      const universityB = await prisma.university.create({
        data: { name: `E2E Uni B ${run}`, code: `E2E-UB-${run}`, active: true },
      });
      const universityInactive = await prisma.university.create({
        data: { name: `E2E Uni inactiva ${run}`, code: `E2E-UI-${run}`, active: false },
      });

      const careerA = await prisma.career.create({
        data: {
          name: `E2E Carrera A ${run}`,
          code: `E2E-CA-${run}`,
          universityId: universityA.id,
          active: true,
        },
      });
      const careerAInactive = await prisma.career.create({
        data: {
          name: `E2E Carrera A inactiva ${run}`,
          code: `E2E-CAI-${run}`,
          universityId: universityA.id,
          active: false,
        },
      });
      const careerB = await prisma.career.create({
        data: {
          name: `E2E Carrera B ${run}`,
          code: `E2E-CB-${run}`,
          universityId: universityB.id,
          active: true,
        },
      });

      const subjectA = await prisma.subject.create({
        data: { name: `E2E Asignatura A ${run}`, code: `E2E-SA-${run}`, careerId: careerA.id },
      });
      const subjectAInactive = await prisma.subject.create({
        data: {
          name: `E2E Asignatura A inactiva ${run}`,
          code: `E2E-SAI-${run}`,
          careerId: careerA.id,
          active: false,
        },
      });
      const subjectB = await prisma.subject.create({
        data: { name: `E2E Asignatura B ${run}`, code: `E2E-SB-${run}`, careerId: careerB.id },
      });

      const professorA = await prisma.professor.create({
        data: {
          name: `E2E Profesor A ${run}`,
          email: email('a'),
          active: true,
          subjects: { connect: [{ id: subjectA.id }] },
        },
      });
      const professorAInactive = await prisma.professor.create({
        data: {
          name: `E2E Profesor A inactivo ${run}`,
          email: email('ai'),
          active: false,
          subjects: { connect: [{ id: subjectA.id }] },
        },
      });
      const professorB = await prisma.professor.create({
        data: {
          name: `E2E Profesor B ${run}`,
          email: email('b'),
          active: true,
          subjects: { connect: [{ id: subjectB.id }] },
        },
      });

      Object.assign(ids, {
        universityA: universityA.id,
        universityB: universityB.id,
        universityInactive: universityInactive.id,
        careerA: careerA.id,
        careerAInactive: careerAInactive.id,
        careerB: careerB.id,
        subjectA: subjectA.id,
        subjectAInactive: subjectAInactive.id,
        subjectB: subjectB.id,
        professorA: professorA.id,
        professorAInactive: professorAInactive.id,
        professorB: professorB.id,
      });
    });

    afterAll(async () => {
      await prisma.professor.deleteMany({
        where: { email: { in: [email('a'), email('ai'), email('b')] } },
      });
      await prisma.university.deleteMany({
        where: {
          id: {
            in: [ids.universityA, ids.universityB, ids.universityInactive].filter(Boolean),
          },
        },
      });
    });

    describe('GET /api/v1/catalog/universities', () => {
      it('incluye las activas y excluye la inactiva', async () => {
        const { body } = await request(app.getHttpServer())
          .get('/api/v1/catalog/universities')
          .expect(200);

        const returnedIds = body.map((u: { id: string }) => u.id);
        expect(returnedIds).toEqual(expect.arrayContaining([ids.universityA, ids.universityB]));
        expect(returnedIds).not.toContain(ids.universityInactive);
      });
    });

    describe('GET /api/v1/catalog/careers', () => {
      it('filtra por universityId y excluye carreras inactivas de otras universidades (200)', async () => {
        const { body } = await request(app.getHttpServer())
          .get('/api/v1/catalog/careers')
          .query({ universityId: ids.universityA })
          .expect(200);

        const returnedIds = body.map((c: { id: string }) => c.id);
        expect(returnedIds).toContain(ids.careerA);
        expect(returnedIds).not.toContain(ids.careerAInactive);
        expect(returnedIds).not.toContain(ids.careerB);
      });

      it('devuelve un arreglo vacío si el padre no tiene carreras (200)', async () => {
        const { body } = await request(app.getHttpServer())
          .get('/api/v1/catalog/careers')
          .query({ universityId: missing.universityId })
          .expect(200);

        expect(body).toEqual([]);
      });

      it('rechaza universityId con formato inválido (400)', async () => {
        await request(app.getHttpServer())
          .get('/api/v1/catalog/careers')
          .query({ universityId: 'no-es-uuid' })
          .expect(400);
      });
    });

    describe('GET /api/v1/catalog/subjects', () => {
      it('filtra por careerId y excluye asignaturas inactivas de otras carreras (200)', async () => {
        const { body } = await request(app.getHttpServer())
          .get('/api/v1/catalog/subjects')
          .query({ careerId: ids.careerA })
          .expect(200);

        const returnedIds = body.map((s: { id: string }) => s.id);
        expect(returnedIds).toContain(ids.subjectA);
        expect(returnedIds).not.toContain(ids.subjectAInactive);
        expect(returnedIds).not.toContain(ids.subjectB);
      });

      it('devuelve un arreglo vacío si el padre no tiene asignaturas (200)', async () => {
        const { body } = await request(app.getHttpServer())
          .get('/api/v1/catalog/subjects')
          .query({ careerId: missing.careerId })
          .expect(200);

        expect(body).toEqual([]);
      });

      it('rechaza careerId con formato inválido (400)', async () => {
        await request(app.getHttpServer())
          .get('/api/v1/catalog/subjects')
          .query({ careerId: 'no-es-uuid' })
          .expect(400);
      });
    });

    describe('GET /api/v1/catalog/professors', () => {
      it('filtra por subjectId y excluye profesores inactivos o de otra asignatura (200)', async () => {
        const { body } = await request(app.getHttpServer())
          .get('/api/v1/catalog/professors')
          .query({ subjectId: ids.subjectA })
          .expect(200);

        const returnedIds = body.map((p: { id: string }) => p.id);
        expect(returnedIds).toContain(ids.professorA);
        expect(returnedIds).not.toContain(ids.professorAInactive);
        expect(returnedIds).not.toContain(ids.professorB);
      });

      it('devuelve un arreglo vacío si la asignatura no tiene profesores (200)', async () => {
        const { body } = await request(app.getHttpServer())
          .get('/api/v1/catalog/professors')
          .query({ subjectId: missing.subjectId })
          .expect(200);

        expect(body).toEqual([]);
      });

      it('rechaza subjectId con formato inválido (400)', async () => {
        await request(app.getHttpServer())
          .get('/api/v1/catalog/professors')
          .query({ subjectId: 'no-es-uuid' })
          .expect(400);
      });
    });
  });
});