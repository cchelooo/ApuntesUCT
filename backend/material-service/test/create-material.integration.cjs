const assert = require('node:assert/strict');
const { test } = require('node:test');
const { randomUUID, createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { resolve } = require('node:path');
const { Client } = require('minio');
const { PrismaClient } = require('.prisma/material-client');
const { NestFactory } = require('@nestjs/core');

test(
  'POST real con PostgreSQL y MinIO aislados',
  { skip: process.env.MATERIAL_TEST_UPLOAD !== '1' },
  async (t) => {
    assert.ok(process.env.MATERIAL_TEST_DATABASE_URL, 'Set MATERIAL_TEST_DATABASE_URL');
    const schema = `material_upload_${randomUUID().replaceAll('-', '')}`;
    const bucket = `material-upload-${randomUUID()}`;
    const url = new URL(process.env.MATERIAL_TEST_DATABASE_URL);
    url.searchParams.set('schema', schema);
    const authorId = randomUUID();
    Object.assign(process.env, {
      DATABASE_URL: url.toString(),
      MINIO_BUCKET: bucket,
      NODE_ENV: 'development',
      MATERIAL_LOCAL_AUTHOR_ENABLED: 'true',
      MATERIAL_LOCAL_UPLOADER_ID: authorId,
    });
    const prisma = new PrismaClient({ datasources: { db: { url: url.toString() } } });
    const { ConfigService } = require('@nestjs/config');
    const { readMinioConfig } = require('../dist/infrastructure/storage/minio.config');
    const minio = new Client(readMinioConfig(new ConfigService(process.env)).client);
    let app;
    let bucketCreated = false;
    const pdf = Buffer.from('%PDF-1.7\nIntegration test file\n%%EOF');
    try {
      execFileSync(
        process.execPath,
        [require.resolve('prisma/build/index.js'), 'migrate', 'deploy'],
        {
          cwd: resolve(__dirname, '..'),
          env: process.env,
          stdio: 'pipe',
        },
      );
      const { AppModule } = require('../dist/app.module');
      const { setupApp } = require('../dist/setup-app');
      const {
        HttpExceptionFilter,
      } = require('../dist/infrastructure/filters/http-exception.filter');
      app = await NestFactory.create(AppModule, { logger: false });
      setupApp(app);
      app.useGlobalFilters(new HttpExceptionFilter());
      await app.listen(0, '127.0.0.1');
      const base = await app.getUrl();
      const post = async (fields = {}, bytes = pdf) => {
        const body = new FormData();
        for (const [key, value] of Object.entries({
          title: 'Apunte de prueba',
          year: '2026',
          type: 'DOCUMENT',
          subjectId: 'subject-test',
          ...fields,
        }))
          body.set(key, value);
        if (bytes !== null)
          body.set('file', new Blob([bytes], { type: 'application/octet-stream' }), 'apuntes.pdf');
        const response = await fetch(`${base}/api/v1/materials`, { method: 'POST', body });
        return { status: response.status, body: await response.json() };
      };
      await t.test('fallo real de MinIO no crea material ni versión', async () => {
        const result = await post(); // Bucket todavía no provisionado.
        assert.equal(result.status, 502);
        assert.equal(await prisma.material.count(), 0);
        assert.equal(await prisma.materialVersion.count(), 0);
        assert.ok(!JSON.stringify(result.body).includes(bucket));
      });
      await minio.makeBucket(bucket);
      bucketCreated = true;
      await t.test('crea archivos de los cuatro tipos con metadatos, autor y versión', async () => {
        for (const type of ['DOCUMENT', 'PRESENTATION', 'EXAM', 'SUMMARY']) {
          const result = await post({
            type,
            description: 'Descripción',
            careerId: 'career-test',
            professorId: 'prof-test',
            externalLink: 'https://example.com/backup',
          });
          assert.equal(result.status, 201);
          assert.equal(result.body.isSimulatedResponse, false);
          const material = await prisma.material.findUniqueOrThrow({
            where: { id: result.body.data.id },
            include: { versions: true, materialType: true },
          });
          assert.equal(material.status, 'PENDING_REVIEW');
          assert.equal(material.verified, false);
          assert.equal(material.uploaderId, authorId);
          assert.equal(material.materialType.name, type);
          assert.equal(material.externalLink, 'https://example.com/backup');
          assert.equal(material.academicYear, 2026);
          assert.equal(material.careerId, 'career-test');
          assert.equal(material.professorId, 'prof-test');
          assert.equal(material.versions.length, 1);
          const version = material.versions[0];
          assert.equal(version.versionNumber, 1);
          assert.equal(version.createdBy, authorId);
          assert.equal(version.fileSize, BigInt(pdf.length));
          assert.equal(version.mimeType, 'application/pdf');
          assert.equal(version.originalFilename, 'apuntes.pdf');
          assert.equal(version.checksum, createHash('sha256').update(pdf).digest('hex'));
          const chunks = [];
          for await (const chunk of await minio.getObject(bucket, version.storageKey))
            chunks.push(chunk);
          assert.deepEqual(Buffer.concat(chunks), pdf);
          assert.equal(result.body.data.fileUrl, null);
          assert.ok(!JSON.stringify(result.body).includes(version.storageKey));
          assert.equal(result.body.data.createdAt, material.createdAt.toISOString());
        }
      });
      await t.test('LINK persiste URL sin archivo ni versión', async () => {
        const result = await post(
          { type: 'LINK', externalLink: 'https://example.com/class' },
          null,
        );
        assert.equal(result.status, 201);
        const material = await prisma.material.findUniqueOrThrow({
          where: { id: result.body.data.id },
          include: { versions: true },
        });
        assert.equal(material.externalLink, 'https://example.com/class');
        assert.equal(material.versions.length, 0);
        assert.equal(result.body.data.fileSize, null);
        assert.equal(result.body.data.mimeType, null);
      });
      await t.test('validaciones HTTP no crean registros', async () => {
        const count = await prisma.material.count();
        assert.equal(
          (await post({ type: 'LINK', externalLink: 'https://example.com' })).status,
          400,
        );
        assert.equal((await post({ type: 'LINK' }, null)).status, 400);
        assert.equal((await post({}, null)).status, 400);
        assert.equal((await post({ externalLink: 'javascript:alert(1)' })).status, 400);
        assert.equal((await post({ uploaderId: randomUUID() })).status, 400);
        assert.equal((await post({}, Buffer.from('not a PDF'))).status, 415);
        await prisma.materialType.update({ where: { name: 'DOCUMENT' }, data: { active: false } });
        assert.equal((await post()).status, 400);
        await prisma.materialType.update({ where: { name: 'DOCUMENT' }, data: { active: true } });
        assert.equal(await prisma.material.count(), count);
      });
      await t.test(
        'el contexto local está bloqueado en producción y cuando está deshabilitado',
        async () => {
          const count = await prisma.material.count();
          try {
            process.env.NODE_ENV = 'production';
            assert.equal(
              (await post({ type: 'LINK', externalLink: 'https://example.com' }, null)).status,
              401,
            );
            process.env.NODE_ENV = 'development';
            process.env.MATERIAL_LOCAL_AUTHOR_ENABLED = 'false';
            assert.equal(
              (await post({ type: 'LINK', externalLink: 'https://example.com' }, null)).status,
              401,
            );
            assert.equal(await prisma.material.count(), count);
          } finally {
            process.env.NODE_ENV = 'development';
            process.env.MATERIAL_LOCAL_AUTHOR_ENABLED = 'true';
          }
        },
      );
      await t.test(
        'un fallo al crear la versión revierte material y elimina el objeto huérfano',
        async () => {
          await prisma.$executeRawUnsafe(
            `CREATE FUNCTION "${schema}".reject_version() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'test rollback' USING ERRCODE = '23503'; END $$`,
          );
          await prisma.$executeRawUnsafe(
            `CREATE TRIGGER reject_version BEFORE INSERT ON "${schema}".material_versions FOR EACH ROW EXECUTE FUNCTION "${schema}".reject_version()`,
          );
          const listKeys = async () => {
            const keys = [];
            for await (const object of minio.listObjectsV2(bucket, '', true))
              keys.push(object.name);
            return keys.sort();
          };
          const beforeKeys = await listKeys();
          const count = await prisma.material.count();
          const result = await post();
          assert.equal(result.status, 500);
          assert.equal(result.body.message, 'Internal server error');
          assert.equal(await prisma.material.count(), count);
          assert.equal(await prisma.materialVersion.count(), 4);
          assert.deepEqual(await listKeys(), beforeKeys);
        },
      );
      await t.test('los materiales pendientes no aparecen en el listado público', async () => {
        const response = await fetch(`${base}/api/v1/materials`);
        assert.equal(response.status, 200);
        assert.equal((await response.json()).total, 0);
      });
    } finally {
      if (app) await app.close();
      await prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
      await prisma.$disconnect();
      if (bucketCreated) {
        for await (const object of minio.listObjectsV2(bucket, '', true))
          await minio.removeObject(bucket, object.name);
        await minio.removeBucket(bucket);
      }
    }
  },
);
