const assert = require('node:assert/strict');
const { randomUUID, createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { test } = require('node:test');

// Ejecutar con un PostgreSQL y MinIO locales de prueba. Recursos aislados por ejecución.
test(
  'HTTP: versiones concurrentes con PostgreSQL y MinIO reales',
  {
    skip: process.env.MATERIAL_TEST_MINIO !== '1' || !process.env.MATERIAL_TEST_DATABASE_URL,
    timeout: 60000,
  },
  async (t) => {
    const { Test } = require('@nestjs/testing');
    const { ConfigService } = require('@nestjs/config');
    const { PrismaClient } = require('.prisma/material-client');
    const { Client } = require('minio');
    const request = require('supertest');
    const {
      CreateMaterialVersion,
    } = require('../dist/application/use-cases/create-material-version');
    const { MaterialsService } = require('../dist/application/services/materials.service');
    const { PrismaService } = require('../dist/infrastructure/prisma/prisma.service');
    const { ObjectStorage } = require('../dist/application/ports/object-storage.port');
    const { MinioStorageAdapter } = require('../dist/infrastructure/storage/minio-storage.adapter');
    const { readMinioConfig } = require('../dist/infrastructure/storage/minio.config');
    const {
      MaterialAuthorProvider,
    } = require('../dist/infrastructure/auth/material-author.provider');
    const {
      MaterialVersionController,
    } = require('../dist/presentation/controllers/material-version.controller');
    const { MaterialsController } = require('../dist/presentation/materials/materials.controller');
    const { setupApp } = require('../dist/setup-app');
    const schema = `versions_minio_${randomUUID().replaceAll('-', '')}`;
    const bucket = `versions-test-${randomUUID()}`;
    const url = new URL(process.env.MATERIAL_TEST_DATABASE_URL);
    url.searchParams.set('schema', schema);
    const prisma = new PrismaClient({ datasources: { db: { url: url.toString() } } });
    const authorId = randomUUID();
    const config = new ConfigService({
      ...process.env,
      MINIO_BUCKET: bucket,
      NODE_ENV: 'development',
      MATERIAL_LOCAL_AUTHOR_ENABLED: 'true',
      MATERIAL_LOCAL_UPLOADER_ID: authorId,
    });
    const client = new Client(readMinioConfig(config).client);
    const storage = new MinioStorageAdapter(config);
    let app;
    let gateway;
    let bucketCreated = false;
    const contents = ['original', 'second', 'third'].map((text) =>
      Buffer.from(`%PDF-1.7\n${text}\n%%EOF`),
    );
    const digest = (buffer) => createHash('sha256').update(buffer).digest('hex');
    try {
      execFileSync(
        process.execPath,
        [require.resolve('prisma/build/index.js'), 'migrate', 'deploy'],
        {
          cwd: require('node:path').resolve(__dirname, '..'),
          env: { ...process.env, DATABASE_URL: url.toString() },
          stdio: 'pipe',
        },
      );
      await client.makeBucket(bucket);
      bucketCreated = true;
      const original = await storage.save(contents[0], 'application/pdf');
      const type = await prisma.materialType.findUniqueOrThrow({ where: { name: 'DOCUMENT' } });
      const material = await prisma.material.create({
        data: {
          uploaderId: authorId,
          subjectId: randomUUID(),
          materialTypeId: type.id,
          title: 'MinIO version test',
          academicYear: 2026,
          status: 'PUBLISHED',
          versions: {
            create: {
              versionNumber: 1,
              storageKey: original.storageKey,
              originalFilename: 'apunte.pdf',
              mimeType: 'application/pdf',
              fileSize: BigInt(contents[0].length),
              checksum: digest(contents[0]),
              createdBy: authorId,
            },
          },
        },
        include: { versions: true },
      });
      const moduleRef = await Test.createTestingModule({
        controllers: [MaterialVersionController, MaterialsController],
        providers: [
          CreateMaterialVersion,
          MaterialsService,
          MaterialAuthorProvider,
          { provide: PrismaService, useValue: prisma },
          { provide: ObjectStorage, useValue: storage },
          { provide: ConfigService, useValue: config },
        ],
      }).compile();
      app = moduleRef.createNestApplication();
      setupApp(app);
      await app.listen(0, '127.0.0.1');
      let httpServer = app.getHttpServer();
      if (process.env.MATERIAL_TEST_GATEWAY === '1') {
        const { AppModule } = require('../../api-gateway/dist/app.module');
        const { configureRoutes } = require('../../api-gateway/dist/configure-routes');
        const gatewayModule = await Test.createTestingModule({ imports: [AppModule] })
          .overrideProvider(ConfigService)
          .useValue(new ConfigService({ MATERIAL_SERVICE_URL: await app.getUrl() }))
          .compile();
        gateway = gatewayModule.createNestApplication();
        configureRoutes(gateway);
        await gateway.init();
        httpServer = gateway.getHttpServer();
        t.diagnostic('Flujo HTTP a través de API Gateway → Material Service.');
      }
      const path = `/api/v1/materials/${material.id}`;
      const responses = await Promise.all(
        contents
          .slice(1)
          .map((content) =>
            request(httpServer)
              .post(`${path}/versions`)
              .attach('file', content, { filename: 'apunte.pdf', contentType: 'application/pdf' })
              .expect(201),
          ),
      );
      assert.deepEqual(responses.map((r) => r.body.versionNumber).sort(), [2, 3]);
      const versions = await prisma.materialVersion.findMany({
        where: { materialId: material.id },
        orderBy: { versionNumber: 'asc' },
      });
      assert.deepEqual(
        versions.map((v) => v.versionNumber),
        [1, 2, 3],
      );
      assert.deepEqual(versions[0], material.versions[0]);
      assert.equal(new Set(versions.map((v) => v.storageKey)).size, 3);
      // La fecha más reciente pertenece a v1: el historial debe ordenar por número.
      await prisma.materialVersion.update({
        where: { id: versions[0].id },
        data: { createdAt: new Date('2099-01-01T00:00:00Z') },
      });
      const { body: detail } = await request(httpServer).get(path).expect(200);
      assert.deepEqual(
        detail.versions.map((v) => v.versionNumber),
        [3, 2, 1],
      );
      assert.deepEqual(detail.currentVersion, detail.versions[0]);
      assert.equal(detail.currentVersion.id, versions[2].id);
      for (const item of detail.versions) {
        const persisted = versions.find((v) => v.id === item.id);
        assert.equal(item.fileSize, persisted.fileSize.toString());
        assert.equal(item.originalFilename, persisted.originalFilename);
        assert.equal(item.mimeType, persisted.mimeType);
      }
      assert.doesNotMatch(JSON.stringify(detail), /storageKey|checksum|createdBy/);
      t.diagnostic(
        'Detalle: historial [3, 2, 1], versión actual v3 y metadatos públicos correctos.',
      );
      const foreignMaterial = await prisma.material.create({
        data: {
          uploaderId: authorId,
          subjectId: randomUUID(),
          materialTypeId: type.id,
          title: 'Otro material de prueba',
          academicYear: 2026,
          status: 'PUBLISHED',
          versions: {
            create: {
              versionNumber: 1,
              storageKey: original.storageKey,
              originalFilename: 'otro.pdf',
              mimeType: 'application/pdf',
              fileSize: BigInt(contents[0].length),
              checksum: digest(contents[0]),
              createdBy: authorId,
            },
          },
        },
        include: { versions: true },
      });
      for (const id of [randomUUID(), foreignMaterial.versions[0].id]) {
        await request(httpServer).get(`${path}/download?versionId=${id}`).expect(404);
      }
      t.diagnostic('Descarga: 404 para versión inexistente y versión de otro material.');
      const expected = new Map([
        [versions[0].id, contents[0]],
        ...responses.map((r, i) => [r.body.id, contents[i + 1]]),
      ]);
      const binaryParser = (res, done) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => done(null, Buffer.concat(chunks)));
        res.on('error', done);
      };
      for (const version of versions) {
        const bytes = expected.get(version.id);
        const stat = await client.statObject(bucket, version.storageKey);
        assert.equal(stat.size, bytes.length);
        assert.equal(stat.metaData['content-type'], 'application/pdf');
        assert.equal(version.checksum, digest(bytes));
        const chunks = [];
        for await (const chunk of await client.getObject(bucket, version.storageKey))
          chunks.push(chunk);
        assert.deepEqual(Buffer.concat(chunks), bytes);
        const response = await request(httpServer)
          .get(`${path}/download?versionId=${version.id}`)
          .buffer(true)
          .parse(binaryParser)
          .expect(200);
        assert.deepEqual(response.body, bytes);
        assert.equal(Number(response.headers['content-length']), bytes.length);
        assert.equal(response.headers['content-type'], 'application/pdf');
        assert.match(response.headers['content-disposition'], /attachment;.*apunte.pdf/);
      }
      const latest = await request(httpServer)
        .get(`${path}/download`)
        .buffer(true)
        .parse(binaryParser)
        .expect(200);
      assert.deepEqual(latest.body, expected.get(versions[2].id));
      const objects = [];
      for await (const object of client.listObjectsV2(bucket, '', true)) objects.push(object);
      assert.equal(objects.length, 3);
      t.diagnostic(
        'Descarga actual e históricas: bytes, SHA-256, MIME y tamaño verificados contra MinIO.',
      );
    } finally {
      // Se intenta cada limpieza incluso si otra falla.
      try {
        try {
          if (gateway) await gateway.close();
        } finally {
          if (app) await app.close();
        }
      } finally {
        try {
          if (bucketCreated) {
            for await (const object of client.listObjectsV2(bucket, '', true)) {
              await client.removeObject(bucket, object.name);
            }
            await client.removeBucket(bucket);
            assert.equal(await client.bucketExists(bucket), false);
          }
        } finally {
          try {
            await prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
            const remaining =
              await prisma.$queryRaw`SELECT schema_name FROM information_schema.schemata WHERE schema_name = ${schema}`;
            assert.equal(remaining.length, 0);
            t.diagnostic('Limpieza verificada: bucket y esquema temporales eliminados.');
          } finally {
            await prisma.$disconnect();
          }
        }
      }
    }
  },
);
