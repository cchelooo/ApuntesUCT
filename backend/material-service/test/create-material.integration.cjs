const assert = require('node:assert/strict');
const { test } = require('node:test');
const { randomUUID, createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { resolve } = require('node:path');

test(
  'POST real con PostgreSQL y MinIO aislados y referencias reales de Catalog',
  { skip: process.env.MATERIAL_TEST_UPLOAD !== '1', timeout: 180000 },
  async (t) => {
    // Cargar dependencias solo cuando la integración está habilitada.
    const { Client } = require('minio');
    const { PrismaClient } = require('.prisma/material-client');
    const { NestFactory } = require('@nestjs/core');
    const { ConfigService } = require('@nestjs/config');
    const { isUUID } = require('class-validator');

    assert.ok(process.env.MATERIAL_TEST_DATABASE_URL, 'Set MATERIAL_TEST_DATABASE_URL');
    const schema = `material_upload_${randomUUID().replaceAll('-', '')}`;
    const bucket = `material-upload-${randomUUID()}`;
    const url = new URL(process.env.MATERIAL_TEST_DATABASE_URL);
    url.searchParams.set('schema', schema);
    const authorId = randomUUID();
    const catalogUrl = new URL(
      process.env.MATERIAL_TEST_CATALOG_SERVICE_URL ||
        process.env.CATALOG_SERVICE_URL ||
        'http://localhost:3002/api/v1',
    );
    assert.ok(['http:', 'https:'].includes(catalogUrl.protocol));
    assert.ok(
      !catalogUrl.username && !catalogUrl.password && !catalogUrl.search && !catalogUrl.hash,
    );
    const catalogBase = catalogUrl.toString().replace(/\/+$/, '');
    const environmentKeys = [
      'DATABASE_URL',
      'MINIO_BUCKET',
      'NODE_ENV',
      'MATERIAL_LOCAL_AUTHOR_ENABLED',
      'MATERIAL_LOCAL_UPLOADER_ID',
      'MATERIAL_LOCAL_UNIVERSITY_ID',
      'CATALOG_SERVICE_URL',
      'CATALOG_TIMEOUT_MS',
    ];
    const previousEnvironment = new Map(environmentKeys.map((key) => [key, process.env[key]]));
    const ownedCatalogPaths = [];
    const refs = {};
    const tag = randomUUID().replaceAll('-', '').slice(0, 8).toUpperCase();
    let prisma;
    let minio;
    let app;
    let bucketCreated = false;
    let primaryError;
    const pdf = Buffer.from('%PDF-1.7\nIntegration test file\n%%EOF');

    const catalogRequest = async (method, path, data, expectedStatus = 201) => {
      const response = await fetch(`${catalogBase}/catalog${path}`, {
        method,
        headers: {
          Accept: 'application/json',
          ...(data ? { 'Content-Type': 'application/json' } : {}),
        },
        ...(data ? { body: JSON.stringify(data) } : {}),
        signal: AbortSignal.timeout(10000),
        redirect: 'error',
      });
      const text = await response.text();
      assert.equal(response.status, expectedStatus, `Catalog ${method} ${path}: ${text}`);
      return text ? JSON.parse(text) : null;
    };
    const createReference = async (path, data) => {
      const result = await catalogRequest('POST', path, data);
      const entity = result?.id ? result : result?.data;
      assert.ok(entity && isUUID(entity.id), `Catalog ${path} debe devolver un UUID válido`);
      ownedCatalogPaths.push(`${path}/${entity.id}`);
      return entity.id;
    };

    try {
      Object.assign(process.env, {
        DATABASE_URL: url.toString(),
        MINIO_BUCKET: bucket,
        NODE_ENV: 'development',
        MATERIAL_LOCAL_AUTHOR_ENABLED: 'true',
        MATERIAL_LOCAL_UPLOADER_ID: authorId,
        CATALOG_SERVICE_URL: catalogBase,
        CATALOG_TIMEOUT_MS: '5000',
      });

      // Preparación por HTTP: ninguna conexión a la BD ni al Prisma de Catalog.
      refs.universityId = await createReference('/universities', {
        name: `Universidad integración ${tag}`,
        code: `U${tag}`,
        active: true,
      });
      refs.careerId = await createReference('/careers', {
        name: `Carrera integración ${tag}`,
        code: `C${tag}`,
        universityId: refs.universityId,
        active: true,
      });
      refs.subjectId = await createReference('/subjects', {
        name: `Asignatura integración ${tag}`,
        code: `S${tag}`,
        semester: 1,
        careerId: refs.careerId,
        active: true,
      });
      refs.professorId = await createReference('/professors', {
        name: `Profesor integración ${tag}`,
        email: `material-${randomUUID()}@example.com`,
        subjectIds: [refs.subjectId],
        active: true,
      });
      process.env.MATERIAL_LOCAL_UNIVERSITY_ID = refs.universityId;

      const tree = await catalogRequest('GET', '', undefined, 200);
      const university = tree.find((entity) => entity.id === refs.universityId && entity.active);
      const career = university?.careers.find(
        (entity) => entity.id === refs.careerId && entity.active,
      );
      assert.ok(career?.subjects.some((entity) => entity.id === refs.subjectId && entity.active));
      const professors = await catalogRequest(
        'GET',
        `/professors?subjectId=${encodeURIComponent(refs.subjectId)}`,
        undefined,
        200,
      );
      assert.ok(professors.some((entity) => entity.id === refs.professorId && entity.active));

      prisma = new PrismaClient({ datasources: { db: { url: url.toString() } } });
      const { readMinioConfig } = require('../dist/infrastructure/storage/minio.config');
      minio = new Client(readMinioConfig(new ConfigService(process.env)).client);
      execFileSync(
        process.execPath,
        [require.resolve('prisma/build/index.js'), 'migrate', 'deploy'],
        { cwd: resolve(__dirname, '..'), env: process.env, stdio: 'pipe', timeout: 120000 },
      );
      // Preparar los tipos locales en el esquema aislado, sin depender de un seed manual.
      for (const name of ['DOCUMENT', 'PRESENTATION', 'EXAM', 'SUMMARY', 'LINK']) {
        await prisma.materialType.upsert({
          where: { name },
          create: { name, active: true },
          update: { active: true },
        });
      }

      const { AppModule } = require('../dist/app.module');
      const { setupApp } = require('../dist/setup-app');
      app = await NestFactory.create(AppModule, { logger: false });
      setupApp(app); // Incluye el filtro real; no registrarlo por segunda vez.
      await app.listen(0, '127.0.0.1');
      const base = await app.getUrl();
      const post = async (fields = {}, bytes = pdf) => {
        const body = new FormData();
        for (const [key, value] of Object.entries({
          title: 'Apunte de prueba',
          year: '2026',
          type: 'DOCUMENT',
          subjectId: refs.subjectId,
          ...fields,
        }))
          body.set(key, value);
        if (bytes !== null) {
          body.set('file', new Blob([bytes], { type: 'application/octet-stream' }), 'apuntes.pdf');
        }
        const response = await fetch(`${base}/api/v1/materials`, {
          method: 'POST',
          body,
          signal: AbortSignal.timeout(15000),
        });
        return { status: response.status, body: await response.json() };
      };
      const listKeys = async () => {
        const keys = [];
        for await (const object of minio.listObjectsV2(bucket, '', true)) keys.push(object.name);
        return keys.sort();
      };
      const snapshot = async () => ({
        materials: await prisma.material.count(),
        versions: await prisma.materialVersion.count(),
        keys: await listKeys(),
      });

      await t.test('fallo real de MinIO no crea material ni versión', async () => {
        const result = await post(); // Catalog válido; bucket todavía no provisionado.
        assert.equal(result.status, 502);
        assert.equal(await prisma.material.count(), 0);
        assert.equal(await prisma.materialVersion.count(), 0);
        assert.ok(!JSON.stringify(result.body).includes(bucket));
      });
      await minio.makeBucket(bucket);
      bucketCreated = true;

      await t.test(
        'crea archivos de los cuatro tipos con referencias reales, autor y versión',
        async () => {
          for (const type of ['DOCUMENT', 'PRESENTATION', 'EXAM', 'SUMMARY']) {
            const result = await post({
              type,
              description: 'Descripción',
              careerId: refs.careerId,
              professorId: refs.professorId,
              externalLink: 'https://example.com/backup',
            });
            assert.equal(result.status, 201, JSON.stringify(result.body));
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
            assert.equal(material.universityId, refs.universityId);
            assert.equal(material.subjectId, refs.subjectId);
            assert.equal(material.careerId, refs.careerId);
            assert.equal(material.professorId, refs.professorId);
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
        },
      );

      await t.test('LINK persiste URL sin archivo ni versión', async () => {
        const result = await post(
          { type: 'LINK', externalLink: 'https://example.com/class' },
          null,
        );
        assert.equal(result.status, 201, JSON.stringify(result.body));
        const material = await prisma.material.findUniqueOrThrow({
          where: { id: result.body.data.id },
          include: { versions: true },
        });
        assert.equal(material.subjectId, refs.subjectId);
        assert.equal(material.universityId, refs.universityId);
        assert.equal(material.externalLink, 'https://example.com/class');
        assert.equal(material.versions.length, 0);
        assert.equal(result.body.data.fileSize, null);
        assert.equal(result.body.data.mimeType, null);
      });

      for (const field of ['subjectId', 'careerId', 'professorId', 'universityId']) {
        await t.test(`referencia inválida conserva field=${field} y no escribe`, async () => {
          const before = await snapshot();
          const previousUniversity = process.env.MATERIAL_LOCAL_UNIVERSITY_ID;
          try {
            const fields = {};
            if (field === 'universityId') process.env.MATERIAL_LOCAL_UNIVERSITY_ID = randomUUID();
            else fields[field] = randomUUID();
            const result = await post(fields);
            assert.equal(result.status, 400, JSON.stringify(result.body));
            assert.equal(result.body.field, field);
            assert.equal(result.body.statusCode, 400);
            assert.equal(result.body.path, '/api/v1/materials');
            assert.ok(!Number.isNaN(Date.parse(result.body.timestamp)));
            assert.deepEqual(await snapshot(), before);
          } finally {
            process.env.MATERIAL_LOCAL_UNIVERSITY_ID = previousUniversity;
          }
        });
      }
      await t.test('LINK inválido también conserva field y evita persistencia', async () => {
        const before = await snapshot();
        const result = await post(
          {
            type: 'LINK',
            externalLink: 'https://example.com/class',
            subjectId: randomUUID(),
          },
          null,
        );
        assert.equal(result.status, 400);
        assert.equal(result.body.field, 'subjectId');
        assert.deepEqual(await snapshot(), before);
      });

      await t.test('validaciones HTTP no crean registros ni objetos', async () => {
        const before = await snapshot();
        assert.equal(
          (await post({ type: 'LINK', externalLink: 'https://example.com' })).status,
          400,
        );
        assert.equal((await post({ type: 'LINK' }, null)).status, 400);
        assert.equal((await post({}, null)).status, 400);
        assert.equal((await post({ externalLink: 'javascript:alert(1)' })).status, 400);
        assert.equal((await post({ uploaderId: randomUUID() })).status, 400);
        assert.equal((await post({}, Buffer.from('not a PDF'))).status, 415);
        try {
          await prisma.materialType.update({
            where: { name: 'DOCUMENT' },
            data: { active: false },
          });
          assert.equal((await post()).status, 400);
        } finally {
          await prisma.materialType.update({ where: { name: 'DOCUMENT' }, data: { active: true } });
        }
        assert.deepEqual(await snapshot(), before);
      });

      await t.test(
        'el contexto local está bloqueado en producción y cuando está deshabilitado',
        async () => {
          const before = await snapshot();
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
            assert.deepEqual(await snapshot(), before);
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
          const before = await snapshot();
          const result = await post();
          assert.equal(result.status, 500);
          assert.equal(result.body.message, 'Internal server error');
          assert.deepEqual(await snapshot(), before);
        },
      );

      await t.test('los materiales pendientes no aparecen en el listado público', async () => {
        const response = await fetch(`${base}/api/v1/materials`, {
          signal: AbortSignal.timeout(15000),
        });
        assert.equal(response.status, 200);
        assert.equal((await response.json()).total, 0);
      });
    } catch (error) {
      primaryError = error;
      throw error;
    } finally {
      // Intentar toda la limpieza aunque falle uno de sus pasos.
      const cleanupErrors = [];
      const cleanup = async (label, action) => {
        try {
          await action();
        } catch (error) {
          cleanupErrors.push(error);
          t.diagnostic(`Limpieza pendiente: ${label}`);
        }
      };
      if (app) await cleanup('cerrar Material', () => app.close());
      if (prisma) {
        await cleanup('esquema aislado', () =>
          prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`),
        );
        await cleanup('conexión de Material', () => prisma.$disconnect());
      }
      if (bucketCreated) {
        await cleanup('objetos del bucket de prueba', async () => {
          for await (const object of minio.listObjectsV2(bucket, '', true)) {
            await minio.removeObject(bucket, object.name);
          }
        });
        await cleanup('bucket de prueba', () => minio.removeBucket(bucket));
      }
      for (const path of ownedCatalogPaths.reverse()) {
        await cleanup(`Catalog ${path}`, async () => {
          const response = await fetch(`${catalogBase}/catalog${path}`, {
            method: 'DELETE',
            signal: AbortSignal.timeout(10000),
            redirect: 'error',
          });
          await response.text();
          assert.ok(
            [200, 204, 404].includes(response.status),
            `DELETE ${path}: ${response.status}`,
          );
        });
      }
      for (const [key, value] of previousEnvironment) {
        if (value === undefined) delete process.env[key];
        else process.env[key] = value;
      }
      if (cleanupErrors.length && !primaryError) {
        throw new AggregateError(
          cleanupErrors,
          'No se pudo completar la limpieza de la integración.',
        );
      }
    }
  },
);
