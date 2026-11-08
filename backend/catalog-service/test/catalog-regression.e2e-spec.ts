import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { randomUUID } from 'node:crypto';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';

// Interfaces tipadas para evitar el uso de 'any' en las pruebas
interface TestSubject {
  id: string;
  name: string;
}

interface TestCareer {
  id: string;
  name: string;
  subjects?: TestSubject[];
}

interface TestUniversity {
  id: string;
  name: string;
  careers?: TestCareer[];
}

interface TestProfessor {
  id: string;
  name?: string;
}

interface TestFilteredSubject {
  id: string;
  professors?: TestProfessor[];
}

describe('Catalog Service - Regresión Reforzada (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  const run = randomUUID().slice(0, 8);
  const email = (suffix: string) => `reg-e2e-${run}-${suffix}@uct.cl`;

  // Variables para almacenar los IDs de los datos sembrados en esta ejecución
  let universityId: string;
  let careerId: string;
  let subjectId: string;
  let professorActiveId: string;
  let professorInactiveId: string;
  const professorOtherId = randomUUID();

  const missingId = '00000000-0000-4000-8000-000000000001';

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();

    app.setGlobalPrefix('api/v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );

    await app.init();
    prisma = app.get(PrismaService);

    // 1. SIEMBRA DE DATOS PROPIOS Y CONTROLADOS
    const uni = await prisma.university.create({
      data: { name: `Reg Uni ${run}`, code: `REG-U-${run}`, active: true },
    });
    universityId = uni.id;

    const car = await prisma.career.create({
      data: {
        name: `Reg Career ${run}`,
        code: `REG-C-${run}`,
        universityId,
        active: true,
      },
    });
    careerId = car.id;

    const sub = await prisma.subject.create({
      data: {
        name: `Reg Subject ${run}`,
        code: `REG-S-${run}`,
        careerId,
        active: true,
      },
    });
    subjectId = sub.id;

    const profAct = await prisma.professor.create({
      data: {
        name: `Reg Prof Activo ${run}`,
        email: email('act'),
        active: true,
        subjects: { connect: [{ id: subjectId }] },
      },
    });
    professorActiveId = profAct.id;

    const profInact = await prisma.professor.create({
      data: {
        name: `Reg Prof Inactivo ${run}`,
        email: email('inact'),
        active: false, // Inactivo para probar exclusión
        subjects: { connect: [{ id: subjectId }] },
      },
    });
    professorInactiveId = profInact.id;

    await prisma.subject.create({
      data: {
        name: `Reg Otra Asignatura ${run}`,
        code: `REG-S-OTHER-${run}`,
        careerId,
        professors: {
          create: {
            id: professorOtherId,
            name: `Reg Prof Ajeno ${run}`,
            email: email('other'),
            active: true,
          },
        },
      },
    });
  });

  afterAll(async () => {
    try {
      if (prisma) {
        await prisma.professor.deleteMany({
          where: {
            email: { in: [email('act'), email('inact'), email('other')] },
          },
        });
        // Si la siembra falla antes de asignar el ID, no ejecutar un borrado
        // cuyo filtro undefined sería omitido por Prisma.
        if (universityId) {
          await prisma.university.deleteMany({
            where: { id: universityId },
          });
        }
      }
    } finally {
      await app?.close();
    }
  });

  // =========================================================================
  // CRITERIO 1: Árbol académico (Universidad → Carrera → Asignatura)
  // =========================================================================
  describe('Criterio 1: Árbol Académico', () => {
    it('GET /api/v1/catalog - verifica la jerarquía completa con datos reales sembrados', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog')
        .expect(200);

      expect(Array.isArray(body)).toBe(true);

      // Buscamos explícitamente nuestra universidad sembrada en el árbol
      const targetUni = (body as TestUniversity[]).find(
        (u) => u.id === universityId,
      );
      expect(targetUni).toBeDefined();
      expect(targetUni?.name).toBe(`Reg Uni ${run}`);

      // Validamos que contenga su carrera correspondiente
      const targetCareer = targetUni?.careers?.find((c) => c.id === careerId);
      expect(targetCareer).toBeDefined();
      expect(targetCareer?.name).toBe(`Reg Career ${run}`);

      // Validamos que la carrera contenga la asignatura correspondiente
      const targetSubject = targetCareer?.subjects?.find(
        (s) => s.id === subjectId,
      );
      expect(targetSubject).toBeDefined();
      expect(targetSubject?.name).toBe(`Reg Subject ${run}`);
    });
  });

  // =========================================================================
  // CRITERIO 2: Filtros hasta professorId (incluyendo activo, inactivo y ajeno)
  // =========================================================================
  describe('Criterio 2: Filtros jerárquicos hasta profesorId', () => {
    it('retorna la asignatura asociada al filtrar por el profesor ACTIVO', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({
          universityId,
          careerId,
          subjectId,
          professorId: professorActiveId,
        })
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
      expect(body.length).toBe(1);

      const subjectResult = (body as TestFilteredSubject[])[0];
      expect(subjectResult.id).toBe(subjectId);

      // Comprobamos que el profesor retornado sea efectivamente el activo
      const returnedProf = subjectResult.professors?.find(
        (p) => p.id === professorActiveId,
      );
      expect(returnedProf).toBeDefined();
    });

    it('devuelve arreglo vacío [] al filtrar por un profesor INACTIVO', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({
          universityId,
          careerId,
          subjectId,
          professorId: professorInactiveId,
        })
        .expect(200);

      expect(Array.isArray(body)).toBe(true);
      expect(body).toEqual([]); // No debe filtrar asignaturas con profesores inactivos
    });

    it.each([
      ['AJENO (vinculado a otra asignatura)', professorOtherId],
      ['INEXISTENTE', missingId],
    ])(
      'devuelve arreglo vacío al filtrar por un profesor %s',
      async (_label, professorId) => {
        const { body } = await request(app.getHttpServer())
          .get('/api/v1/catalog/filter')
          .query({
            universityId,
            careerId,
            subjectId,
            professorId,
          })
          .expect(200);

        expect(Array.isArray(body)).toBe(true);
        expect(body).toEqual([]);
      },
    );
  });

  // =========================================================================
  // CRITERIO 3: Indiferencia ante parámetros year / type de Material/Search
  // =========================================================================
  describe('Criterio 3: Independencia de year y type', () => {
    it('consultar con y sin year/type devuelve exactamente los mismos resultados', async () => {
      const queryBase = { universityId, careerId };

      // Consulta limpia
      const resWithout = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query(queryBase)
        .expect(200);

      // Consulta enviando parámetros ajenos al dominio de catálogo
      const resWith = await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({
          ...queryBase,
          year: 2026,
          type: 'APUNTE',
        })
        .expect(200);

      // Se comprueba que Catalog ignora de forma segura estos campos y retorna idéntico set de datos
      expect(resWith.body).toEqual(resWithout.body);
      expect((resWith.body as unknown[]).length).toBeGreaterThan(0);
    });
  });

  // =========================================================================
  // CRITERIO 4: Endpoints individuales y validaciones generales
  // =========================================================================
  describe('Criterio 4: Endpoints individuales y estabilidad', () => {
    it('GET /api/v1/catalog/universities - incluye la universidad recién sembrada', async () => {
      const { body } = await request(app.getHttpServer())
        .get('/api/v1/catalog/universities')
        .expect(200);

      const found = (body as TestUniversity[]).find(
        (u) => u.id === universityId,
      );
      expect(found).toBeDefined();
    });

    it('rechaza una secuencia jerárquica incompleta con HTTP 400', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/catalog/filter')
        .query({ careerId }) // Falta universityId obligatorio por jerarquía
        .expect(400);
    });
  });
});
