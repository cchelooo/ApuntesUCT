const assert = require('node:assert/strict');
const { randomUUID, createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { resolve } = require('node:path');
const { test } = require('node:test');
const { jwtFixture } = require('../../test/jwt-fixture.cjs');

// Build material-service and api-gateway first. Uses real providers throughout;
// only fixture records and signed identities are created by the test.
test('administración #460: Gateway → Material → PostgreSQL/MinIO reales', {
  skip: process.env.MATERIAL_TEST_MINIO !== '1' || !process.env.MATERIAL_TEST_DATABASE_URL,
  timeout: 60000,
}, async (t) => {
  const { NestFactory } = require('@nestjs/core');
  const { PrismaClient } = require('.prisma/material-client');
  const { Client } = require('minio');
  const schema = `admin_test_${randomUUID().replaceAll('-', '')}`;
  const bucket = `admin-test-${randomUUID()}`;
  const url = new URL(process.env.MATERIAL_TEST_DATABASE_URL);
  url.searchParams.set('schema', schema);
  const identity = jwtFixture();
  const settings = {
    ...identity.settings, DATABASE_URL: url.toString(), MINIO_BUCKET: bucket,
    NODE_ENV: 'test', MATERIAL_SERVICE_URL: '',
  };
  const previous = Object.fromEntries(Object.keys(settings).map(key => [key, process.env[key]]));
  Object.assign(process.env, settings);
  const prisma = new PrismaClient({ datasources: { db: { url: url.toString() } } });
  const { ConfigService } = require('@nestjs/config');
  const { readMinioConfig } = require('../dist/infrastructure/storage/minio.config');
  const client = new Client(readMinioConfig(new ConfigService(process.env)).client);
  let app, gateway, bucketCreated = false;
  const digest = bytes => createHash('sha256').update(bytes).digest('hex');
  try {
    execFileSync(process.execPath, [require.resolve('prisma/build/index.js'), 'migrate', 'deploy'], {
      cwd: resolve(__dirname, '..'), env: process.env, stdio: 'pipe',
    });
    await client.makeBucket(bucket);
    bucketCreated = true;
    const { AppModule } = require('../dist/app.module');
    app = await NestFactory.create(AppModule, { logger: false });
    require('../dist/setup-app').setupApp(app);
    await app.listen(0, '127.0.0.1');
    process.env.MATERIAL_SERVICE_URL = await app.getUrl();
    gateway = await NestFactory.create(require('../../api-gateway/dist/app.module').AppModule, { logger: false });
    require('../../api-gateway/dist/configure-routes').configureRoutes(gateway);
    await gateway.listen(0, '127.0.0.1');
    const base = await gateway.getUrl();
    const get = async (path, status = 200, role) => {
      const headers = role ? { Authorization: identity.authorization(randomUUID(), role) } : {};
      const response = await fetch(`${base}/api/v1/materials${path}`, { headers });
      assert.equal(response.status, status, `${path}: expected ${status}`);
      return response;
    };
    const type = await prisma.materialType.findUniqueOrThrow({ where: { name: 'DOCUMENT' } });
    const fixtures = [];
    for (const status of ['PENDING_REVIEW', 'PENDING_REVIEW', 'PUBLISHED', 'REJECTED', 'RETIRED']) {
      const uploaderId = randomUUID();
      const material = await prisma.material.create({ data: {
        uploaderId, subjectId: randomUUID(), materialTypeId: type.id,
        title: `Integration ${status}`, academicYear: 2026, status,
      } });
      const versions = [];
      for (const number of [1, 2]) {
        const bytes = Buffer.from(`%PDF-1.7\n${material.id} version ${number}\n%%EOF`);
        const storageKey = `private/${randomUUID()}`;
        await client.putObject(bucket, storageKey, bytes, bytes.length, { 'Content-Type': 'application/pdf' });
        const version = await prisma.materialVersion.create({ data: {
          materialId: material.id, versionNumber: number, storageKey,
          originalFilename: `apunte-${number}.pdf`, mimeType: 'application/pdf',
          fileSize: BigInt(bytes.length), checksum: digest(bytes), createdBy: uploaderId,
        } });
        versions.push({ ...version, bytes });
      }
      fixtures.push({ ...material, versions });
    }
    const pending = fixtures[0];
    const root = '/admin/pending';
    const detail = `${root}/${pending.id}`;
    await t.test('401 sin JWT y 403 para STUDENT en las tres rutas', async () => {
      for (const path of [root, detail, `${detail}/download`]) {
        await get(path, 401);
        await get(path, 403, 'STUDENT');
      }
    });
    await t.test('MODERATOR y ADMIN: paginación, detalle, descarga actual e histórica', async () => {
      for (const role of ['MODERATOR', 'ADMIN']) {
        const pages = [];
        for (const page of [1, 2, 3]) {
          const response = await get(`${root}?page=${page}&pageSize=1`, 200, role);
          assert.equal(response.headers.get('cache-control'), 'no-store');
          const body = await response.json();
          assert.equal(body.total, 2);
          assert.equal(body.page, page);
          assert.equal(body.items.length, page === 3 ? 0 : 1);
          assert.ok(body.items.every(item => item.status === 'PENDING_REVIEW'));
          pages.push(...body.items.map(item => item.id));
        }
        assert.equal(new Set(pages).size, 2);
        const body = await (await get(detail, 200, role)).json();
        assert.deepEqual(body.versions.map(version => version.versionNumber), [2, 1]);
        assert.doesNotMatch(JSON.stringify(body), /storageKey|checksum|private\//);
        for (const version of pending.versions) {
          const response = await get(`${detail}/download?versionId=${version.id}`, 200, role);
          const bytes = Buffer.from(await response.arrayBuffer());
          assert.equal(digest(bytes), version.checksum);
          assert.deepEqual(bytes, version.bytes);
          assert.equal(response.headers.get('content-length'), String(bytes.length));
          assert.equal(response.headers.get('content-type'), 'application/pdf');
          assert.match(response.headers.get('content-disposition'), /^attachment;/);
          assert.equal(response.headers.get('cache-control'), 'no-store');
          assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
          assert.doesNotMatch(JSON.stringify([...response.headers]), /minio|storageKey|private\//i);
        }
        assert.deepEqual(Buffer.from(await (await get(`${detail}/download`, 200, role)).arrayBuffer()), pending.versions[1].bytes);
        await get(`${detail}/download?versionId=${fixtures[1].versions[0].id}`, 404, role);
      }
    });
    await t.test('rutas públicas ocultan pendientes, rechazados y retirados', async () => {
      const page = await (await get('')).json();
      assert.deepEqual(page.items.map(item => item.id), [fixtures[2].id]);
      for (const material of fixtures.filter(item => item.status !== 'PUBLISHED')) {
        for (const suffix of ['', '/download', '/preview']) await get(`/${material.id}${suffix}`, 404);
      }
      assert.deepEqual(Buffer.from(await (await get(`/${fixtures[2].id}/download`)).arrayBuffer()), fixtures[2].versions[1].bytes);
    });
    await t.test('rutas administrativas rechazan los otros estados y objetos ausentes', async () => {
      for (const material of fixtures.slice(2)) {
        await get(`${root}/${material.id}`, 404, 'ADMIN');
        await get(`${root}/${material.id}/download`, 404, 'ADMIN');
      }
      await client.removeObject(bucket, pending.versions[1].storageKey);
      await get(`${detail}/download`, 404, 'ADMIN');
    });
    await t.test('MinIO impide la descarga anónima directa', async () => {
      const protocol = process.env.MINIO_USE_SSL === 'true' ? 'https' : 'http';
      const response = await fetch(`${protocol}://${process.env.MINIO_ENDPOINT}:${process.env.MINIO_PORT || 9000}/${bucket}/${pending.versions[0].storageKey}`);
      assert.equal(response.status, 403);
    });
  } finally {
    try {
      try { if (gateway) await gateway.close(); }
      finally { if (app) await app.close(); }
    } finally {
      try {
        if (bucketCreated) {
          for await (const object of client.listObjectsV2(bucket, '', true)) await client.removeObject(bucket, object.name);
          await client.removeBucket(bucket);
          assert.equal(await client.bucketExists(bucket), false);
        }
      } finally {
        try {
          await prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
          const remaining = await prisma.$queryRaw`SELECT schema_name FROM information_schema.schemata WHERE schema_name = ${schema}`;
          assert.equal(remaining.length, 0);
          t.diagnostic('Bucket y esquema temporales eliminados; limpieza verificada.');
        } finally {
          await prisma.$disconnect();
          for (const [key, value] of Object.entries(previous)) {
            if (value === undefined) delete process.env[key]; else process.env[key] = value;
          }
        }
      }
    }
  }
});
