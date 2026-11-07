// Prueba explícita sobre una quality_db de desarrollo. Nunca usa bases de otros servicios.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { randomUUID } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { resolve } = require('node:path');
const { PrismaClient } = require('.prisma/quality-client');
const { NestFactory } = require('@nestjs/core');

const cwd = resolve(__dirname, '..');

test(
  'Quality: PostgreSQL real, migración reproducible y aislamiento',
  { timeout: 120000 },
  async (t) => {
    assert.ok(
      process.env.QUALITY_TEST_DATABASE_URL,
      'Configura QUALITY_TEST_DATABASE_URL con una quality_db LOCAL.',
    );
    const url = new URL(process.env.QUALITY_TEST_DATABASE_URL);
    assert.ok(['postgres:', 'postgresql:'].includes(url.protocol));
    assert.equal(url.pathname, '/quality_db', 'La prueba solo admite la base quality_db.');
    const schema = `quality_test_${randomUUID().replaceAll('-', '')}`;
    url.searchParams.set('schema', schema);
    const previousUrl = process.env.DATABASE_URL;
    process.env.DATABASE_URL = url.toString();
    const prisma = new PrismaClient({ datasources: { db: { url: url.toString() } } });
    const deploy = () =>
      execFileSync(
        process.execPath,
        [require.resolve('prisma/build/index.js'), 'migrate', 'deploy'],
        {
          cwd,
          env: { ...process.env, DATABASE_URL: url.toString() },
          stdio: 'pipe',
          timeout: 60000,
        },
      );
    let app;
    try {
      deploy();
      const materialId = randomUUID();
      const userId = randomUUID();
      let favorite;
      await t.test(
        'crea las cuatro entidades con referencias lógicas sin Auth o Material',
        async () => {
          const review = await prisma.review.create({
            data: { materialId, userId, decision: 'ACCEPT' },
          });
          assert.equal(review.purpose, 'MODERATION');
          const rating = await prisma.rating.create({ data: { materialId, userId, score: 5 } });
          assert.equal(rating.score, 5);
          const report = await prisma.report.create({
            data: { materialId, userId, reason: 'Contenido incorrecto' },
          });
          assert.equal(report.status, 'OPEN');
          favorite = await prisma.favorite.create({ data: { materialId, userId } });
          assert.equal(favorite.materialId, materialId);
        },
      );
      await t.test('guarda evidencia de verificación e historial de revisiones', async () => {
        await prisma.review.create({
          data: {
            materialId,
            userId,
            purpose: 'VERIFICATION',
            decision: 'ACCEPT',
            materialVersionId: randomUUID(),
          },
        });
        await prisma.review.create({
          data: { materialId, userId, decision: 'REQUEST_CHANGES', comment: 'Revisar contenido' },
        });
        assert.equal(await prisma.review.count({ where: { materialId, userId } }), 3);
      });
      await t.test('impide duplicar favoritos y calificaciones por usuario/material', async () => {
        await assert.rejects(prisma.favorite.create({ data: { materialId, userId } }), {
          code: 'P2002',
        });
        await assert.rejects(prisma.rating.create({ data: { materialId, userId, score: 4 } }), {
          code: 'P2002',
        });
      });
      await t.test(
        'admite los extremos de Rating y permite actualizar la nota vigente',
        async () => {
          await prisma.rating.create({ data: { materialId, userId: randomUUID(), score: 1 } });
          await prisma.rating.update({
            where: { materialId_userId: { materialId, userId } },
            data: { score: 3 },
          });
          assert.equal(
            (
              await prisma.rating.findUniqueOrThrow({
                where: { materialId_userId: { materialId, userId } },
              })
            ).score,
            3,
          );
        },
      );
      await t.test(
        'CHECK PostgreSQL rechaza notas fuera de 1..5 incluso sin validación HTTP',
        async () => {
          for (const score of [0, 6]) {
            await assert.rejects(
              prisma.rating.create({ data: { materialId, userId: randomUUID(), score } }),
              /ratings_score_range/,
            );
          }
        },
      );
      await t.test(
        'no existen claves foráneas ni columnas de estado público de Material',
        async () => {
          const foreignKeys =
            await prisma.$queryRaw`SELECT constraint_name FROM information_schema.table_constraints WHERE constraint_schema = ${schema} AND constraint_type = 'FOREIGN KEY'`;
          assert.equal(foreignKeys.length, 0);
          const columns =
            await prisma.$queryRaw`SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = ${schema} AND table_name IN ('reviews','ratings','reports','favorites')`;
          assert.ok(
            !columns.some((column) =>
              ['verified', 'material_status', 'publication_status'].includes(column.column_name),
            ),
          );
          assert.ok(
            !columns.some(
              (column) => column.table_name !== 'reports' && column.column_name === 'status',
            ),
          );
          const states =
            await prisma.$queryRaw`SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid JOIN pg_namespace n ON n.oid = t.typnamespace WHERE n.nspname = ${schema}`;
          assert.ok(
            !states.some((state) =>
              ['PENDING_REVIEW', 'PUBLISHED', 'REJECTED', 'WITHDRAWN'].includes(state.enumlabel),
            ),
          );
        },
      );
      await t.test(
        'repetir migrate deploy conserva los registros y no reaplica la migración',
        async () => {
          deploy();
          assert.equal(await prisma.review.count(), 3);
          assert.equal(await prisma.rating.count(), 2);
          assert.equal(await prisma.report.count(), 1);
          assert.equal(
            (await prisma.favorite.findUniqueOrThrow({ where: { id: favorite.id } })).id,
            favorite.id,
          );
          const migrations = await prisma.$queryRawUnsafe(
            `SELECT migration_name, finished_at FROM "${schema}"."_prisma_migrations" WHERE rolled_back_at IS NULL`,
          );
          assert.equal(migrations.length, 1);
          assert.ok(migrations[0].finished_at);
        },
      );
      await t.test(
        'la aplicación inicia con PostgreSQL real y publica salud y Swagger',
        async () => {
          const { AppModule } = require('../dist/app.module');
          const { setupApp } = require('../dist/setup-app');
          app = await NestFactory.create(AppModule, { logger: false });
          setupApp(app);
          await app.listen(0, '127.0.0.1');
          const base = await app.getUrl();
          const health = await fetch(`${base}/health`);
          assert.equal(health.status, 200);
          assert.deepEqual(await health.json(), {
            status: 'ok',
            service: 'quality-service',
            database: 'up',
          });
          const specResponse = await fetch(`${base}/api/docs-json`);
          assert.equal(specResponse.status, 200);
          const spec = await specResponse.json();
          assert.ok(spec.paths['/health']);
        },
      );
    } finally {
      try {
        if (app) await app.close();
      } finally {
        try {
          // El esquema fue generado aquí con caracteres [a-z0-9_]; nunca se borra public.
          await prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
        } finally {
          await prisma.$disconnect();
          if (previousUrl === undefined) delete process.env.DATABASE_URL;
          else process.env.DATABASE_URL = previousUrl;
        }
      }
    }
  },
);
