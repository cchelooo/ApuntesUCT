const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { test } = require('node:test');
const { Readable } = require('node:stream');

// PostgreSQL real; almacenamiento en memoria para aislar numeración y persistencia.
test(
  'versiones concurrentes conservan filas, objetos y descarga histórica',
  {
    skip: !process.env.MATERIAL_TEST_DATABASE_URL,
  },
  async () => {
    const { PrismaClient } = require('.prisma/material-client');
    const {
      CreateMaterialVersion,
    } = require('../dist/application/use-cases/create-material-version');
    const { MaterialsService } = require('../dist/application/services/materials.service');
    const schema = `material_versions_${randomUUID().replaceAll('-', '')}`;
    const url = new URL(process.env.MATERIAL_TEST_DATABASE_URL);
    url.searchParams.set('schema', schema);
    const prisma = new PrismaClient({ datasources: { db: { url: url.toString() } } });
    const objects = new Map([['original-object', Buffer.from('original content')]]);
    const storage = {
      async save(buffer) {
        const storageKey = randomUUID();
        objects.set(storageKey, Buffer.from(buffer));
        return { storageKey };
      },
      async get(key) {
        return Readable.from([objects.get(key)]);
      },
      async remove(key) {
        objects.delete(key);
      },
    };
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
      const author = { id: randomUUID(), universityId: null };
      const type = await prisma.materialType.create({ data: { name: 'VERSION_TEST' } });
      const material = await prisma.material.create({
        data: {
          uploaderId: author.id,
          subjectId: randomUUID(),
          materialTypeId: type.id,
          title: 'Version test',
          academicYear: 2026,
          status: 'PUBLISHED',
          versions: {
            create: {
              versionNumber: 1,
              storageKey: 'original-object',
              originalFilename: 'apunte.pdf',
              mimeType: 'application/pdf',
              fileSize: 16n,
              checksum: 'original-checksum',
              createdBy: author.id,
            },
          },
        },
        include: { versions: true },
      });
      const create = new CreateMaterialVersion(prisma, storage);
      const uploaded = await Promise.all(
        ['second', 'third'].map((content) =>
          create.execute(material.id, author, {
            buffer: Buffer.from(content),
            originalname: 'apunte.pdf',
            mimetype: 'application/pdf',
          }),
        ),
      );
      assert.deepEqual(uploaded.map((v) => v.versionNumber).sort(), [2, 3]);
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
      assert.equal(objects.size, 3);
      for (const version of versions) {
        const download = await new MaterialsService(prisma, storage).download(
          material.id,
          version.id,
        );
        const chunks = [];
        for await (const chunk of download.stream) chunks.push(chunk);
        assert.deepEqual(Buffer.concat(chunks), objects.get(version.storageKey));
      }
      const latest = await new MaterialsService(prisma, storage).detail(material.id);
      assert.equal(latest.currentVersion.versionNumber, 3);
    } finally {
      await prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
      await prisma.$disconnect();
    }
  },
);
