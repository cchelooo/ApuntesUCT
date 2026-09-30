import { PrismaClient } from '@prisma/client';

describe('Migración de base de datos: Columna semester en subjects', () => {
  let prisma: PrismaClient;

  beforeAll(async () => {
    prisma = new PrismaClient();
    await prisma.$connect();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('debe conservar las asignaturas preexistentes y asignar semester = 1 a los registros con NULL', async () => {
    // 1. Crear una tabla de prueba temporal que simula "subjects" ANTES de la migración
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "subjects_migration_test" (
        "id" TEXT PRIMARY KEY,
        "name" TEXT NOT NULL,
        "code" TEXT NOT NULL
      )
    `);

    // 2. Insertar una asignatura simulando datos preexistentes sin la columna semester
    await prisma.$executeRawUnsafe(`
      INSERT INTO "subjects_migration_test" ("id", "name", "code")
      VALUES ('sub-legacy-01', 'Cálculo I', 'MAT-101')
      ON CONFLICT ("id") DO NOTHING
    `);

    // 3. Ejecutar la secuencia exacta de la migración paso a paso (sentencias individuales)
    await prisma.$executeRawUnsafe(
      `ALTER TABLE "subjects_migration_test" ADD COLUMN IF NOT EXISTS "semester" INTEGER`,
    );
    await prisma.$executeRawUnsafe(
      `UPDATE "subjects_migration_test" SET "semester" = 1 WHERE "semester" IS NULL`,
    );
    await prisma.$executeRawUnsafe(
      `ALTER TABLE "subjects_migration_test" ALTER COLUMN "semester" SET DEFAULT 1`,
    );
    await prisma.$executeRawUnsafe(
      `ALTER TABLE "subjects_migration_test" ALTER COLUMN "semester" SET NOT NULL`,
    );

    // 4. Verificar que la asignatura previa no se borró y obtuvo semester = 1
    const result: Array<{ id: string; name: string; semester: number }> =
      await prisma.$queryRawUnsafe(
        `SELECT "id", "name", "semester" FROM "subjects_migration_test" WHERE "id" = 'sub-legacy-01'`,
      );

    expect(result).toHaveLength(1);
    expect(result[0].name).toBe('Cálculo I');
    expect(result[0].semester).toBe(1);

    // 5. Limpieza de la tabla de prueba
    await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS "subjects_migration_test"`);
  });
});