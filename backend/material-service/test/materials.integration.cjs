const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { resolve } = require('node:path');
const { test } = require('node:test');
const { PrismaClient } = require('.prisma/material-client');
const { NestFactory } = require('@nestjs/core');

// Requires npm run build. Uses real HTTP and Prisma with an isolated schema.
test('paginated materials over HTTP with PostgreSQL', async (t) => {
  assert.ok(process.env.MATERIAL_TEST_DATABASE_URL, 'Set MATERIAL_TEST_DATABASE_URL');
  const schema = `material_http_test_${randomUUID().replaceAll('-', '')}`;
  const url = new URL(process.env.MATERIAL_TEST_DATABASE_URL);
  url.searchParams.set('schema', schema);
  const databaseUrl = url.toString();
  const previousDatabaseUrl = process.env.DATABASE_URL;
  process.env.DATABASE_URL = databaseUrl;
  const prisma = new PrismaClient({ datasources: { db: { url: databaseUrl } } });
  let app;
  try {
    execFileSync(
      process.execPath,
      [require.resolve('prisma/build/index.js'), 'migrate', 'deploy'],
      {
        cwd: resolve(__dirname, '..'),
        env: { ...process.env, DATABASE_URL: databaseUrl },
        stdio: 'pipe',
      },
    );
    const { AppModule } = require('../dist/app.module');
    const { setupApp } = require('../dist/setup-app');
    app = await NestFactory.create(AppModule, { logger: false });
    setupApp(app);
    await app.listen(0, '127.0.0.1');
    const base = await app.getUrl();
    const get = async (query = '', status = 200) => {
      const response = await fetch(`${base}/api/v1/materials${query}`);
      assert.equal(response.status, status);
      return response.json();
    };
    await t.test('empty database returns 200 and zero total', async () => {
      assert.deepEqual(await get(), { items: [], page: 1, pageSize: 20, total: 0 });
    });
    const type = await prisma.materialType.create({ data: { name: 'CLASS_NOTES' } });
    const common = {
      uploaderId: randomUUID(),
      subjectId: 'calculo-1',
      materialTypeId: type.id,
      academicYear: 2026,
      description: null,
    };
    const ids = [1, 2, 3].map((n) => `00000000-0000-4000-8000-00000000000${n}`);
    await prisma.material.createMany({
      data: [
        ...ids.map((id, index) => ({
          ...common,
          id,
          title: `Publicado ${index + 1}`,
          status: 'PUBLISHED',
          createdAt: new Date(index === 0 ? '2026-09-01T12:00:00Z' : '2026-10-01T12:00:00Z'),
        })),
        ...['PENDING_REVIEW', 'REJECTED', 'WITHDRAWN'].map((status) => ({
          ...common,
          title: `Oculto ${status}`,
          status,
          createdAt: new Date('2026-10-02T12:00:00Z'),
        })),
      ],
    });
    await prisma.materialVersion.create({
      data: {
        materialId: ids[2],
        versionNumber: 1,
        storageKey: 'private/test.pdf',
        originalFilename: 'test.pdf',
        mimeType: 'application/pdf',
        fileSize: 1024n,
        checksum: 'test',
        createdBy: common.uploaderId,
      },
    });
    await t.test('queries filter visibility and sort tied dates across pages', async () => {
      const first = await get('?page=1&pageSize=2');
      const second = await get('?page=2&pageSize=2');
      assert.deepEqual(
        first.items.map((item) => item.id),
        [ids[2], ids[1]],
      );
      assert.deepEqual(
        second.items.map((item) => item.id),
        [ids[0]],
      );
      assert.equal(first.total, 3);
      assert.equal(second.total, 3);
      assert.equal(first.pageSize, 2);
      assert.equal(second.page, 2);
      assert.deepEqual(await get('?page=1&pageSize=2'), first);
      const item = first.items[0];
      assert.equal(item.materialType, 'CLASS_NOTES');
      assert.equal(item.description, null);
      assert.equal(item.status, 'PUBLISHED');
      assert.equal(item.createdAt, '2026-10-01T12:00:00.000Z');
      assert.equal(item.versions, undefined);
      assert.equal(item.storageKey, undefined);
    });
    await t.test('page past the end retains the actual total', async () => {
      assert.deepEqual(await get('?page=3&pageSize=2'), {
        items: [],
        page: 3,
        pageSize: 2,
        total: 3,
      });
    });
    await t.test('invalid and search parameters return 400', async () => {
      for (const query of ['?page=0', '?pageSize=101', '?page=1&page=2', '?q=calculo']) {
        assert.equal((await get(query, 400)).statusCode, 400);
      }
    });
    await t.test('only unpublished materials returns empty', async () => {
      await prisma.material.updateMany({
        where: { status: 'PUBLISHED' },
        data: { status: 'WITHDRAWN' },
      });
      assert.deepEqual(await get(), { items: [], page: 1, pageSize: 20, total: 0 });
    });
  } finally {
    try {
      if (app) await app.close();
    } finally {
      try {
        await prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
        const remaining =
          await prisma.$queryRaw`SELECT schema_name FROM information_schema.schemata WHERE schema_name = ${schema}`;
        assert.equal(remaining.length, 0, 'Temporary schema must be removed');
      } finally {
        await prisma.$disconnect();
        if (previousDatabaseUrl === undefined) delete process.env.DATABASE_URL;
        else process.env.DATABASE_URL = previousDatabaseUrl;
      }
    }
  }
});
