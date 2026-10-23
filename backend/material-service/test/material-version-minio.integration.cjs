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
  async () => {
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
      await app.init();
      const path = `/api/v1/materials/${material.id}`;
      const responses = await Promise.all(
        contents
          .slice(1)
          .map((content) =>
            request(app.getHttpServer())
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
        const response = await request(app.getHttpServer())
          .get(`${path}/download?versionId=${version.id}`)
          .buffer(true)
          .parse(binaryParser)
          .expect(200);
        assert.deepEqual(response.body, bytes);
        assert.equal(Number(response.headers['content-length']), bytes.length);
      }
      const latest = await request(app.getHttpServer())
        .get(`${path}/download`)
        .buffer(true)
        .parse(binaryParser)
        .expect(200);
      assert.deepEqual(latest.body, expected.get(versions[2].id));
      const objects = [];
      for await (const object of client.listObjectsV2(bucket, '', true)) objects.push(object);
      assert.equal(objects.length, 3);
    } finally {
      // Se intenta cada limpieza incluso si otra falla.
      try {
        if (app) await app.close();
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
          } finally {
            await prisma.$disconnect();
          }
        }
      }
    }
  },
);
