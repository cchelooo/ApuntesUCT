const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { test } = require('node:test');
const { PrismaClient } = require('.prisma/material-client');

// Uses a disposable schema, never resets or migrates the application's schema.
test('migration and material version persistence in PostgreSQL', async () => {
  assert.ok(
    process.env.MATERIAL_TEST_DATABASE_URL,
    'Set MATERIAL_TEST_DATABASE_URL to a PostgreSQL test database',
  );
  const schema = `material_test_${randomUUID().replaceAll('-', '')}`;
  const url = new URL(process.env.MATERIAL_TEST_DATABASE_URL);
  url.searchParams.set('schema', schema);
  const databaseUrl = url.toString();
  const prisma = new PrismaClient({ datasources: { db: { url: databaseUrl } } });
  const migrate = () =>
    execFileSync(
      process.execPath,
      [require.resolve('prisma/build/index.js'), 'migrate', 'deploy'],
      {
        cwd: require('node:path').resolve(__dirname, '..'),
        env: { ...process.env, DATABASE_URL: databaseUrl },
        encoding: 'utf8',
      },
    );

  try {
    migrate();
    assert.match(migrate(), /No pending migrations/);
    const type = await prisma.materialType.create({ data: { name: 'CLASS_NOTES' } });
    const uploaderId = randomUUID();
    const material = await prisma.material.create({
      data: {
        uploaderId,
        subjectId: 'external-subject',
        professorId: 'external-professor',
        materialTypeId: type.id,
        title: 'Apuntes de prueba',
        academicYear: 2026,
      },
    });
    assert.equal(material.status, 'PENDING_REVIEW');
    assert.equal(material.verified, false);
    const version = {
      materialId: material.id,
      versionNumber: 1,
      storageKey: `${material.id}/1.pdf`,
      originalFilename: 'apuntes.pdf',
      mimeType: 'application/pdf',
      fileSize: 1024n,
      checksum: 'test-checksum',
      createdBy: uploaderId,
    };
    await prisma.materialVersion.create({ data: version });
    await prisma.materialVersion.create({
      data: { ...version, versionNumber: 2, storageKey: `${material.id}/2.pdf` },
    });
    const saved = await prisma.material.findUniqueOrThrow({
      where: { id: material.id },
      include: { versions: { orderBy: { versionNumber: 'asc' } } },
    });
    assert.deepEqual(
      saved.versions.map((v) => v.versionNumber),
      [1, 2],
    );
    assert.equal(saved.versions[0].fileSize, 1024n);
    await assert.rejects(prisma.materialVersion.create({ data: version }), { code: 'P2002' });
    await assert.rejects(
      prisma.materialVersion.create({ data: { ...version, materialId: randomUUID() } }),
      { code: 'P2003' },
    );
    await assert.rejects(prisma.material.delete({ where: { id: material.id } }), { code: 'P2003' });
    const foreignKeys = await prisma.$queryRaw`
      SELECT tc.table_name, ccu.table_name AS target_table, ccu.table_schema AS target_schema
      FROM information_schema.table_constraints tc
      JOIN information_schema.constraint_column_usage ccu
        ON tc.constraint_name = ccu.constraint_name AND tc.constraint_schema = ccu.constraint_schema
      WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = ${schema}
      ORDER BY tc.table_name
    `;
    assert.deepEqual(foreignKeys, [
      { table_name: 'material_versions', target_table: 'materials', target_schema: schema },
      { table_name: 'materials', target_table: 'material_types', target_schema: schema },
    ]);
    const diff = execFileSync(
      process.execPath,
      [
        require.resolve('prisma/build/index.js'),
        'migrate',
        'diff',
        '--from-url',
        databaseUrl,
        '--to-schema-datamodel',
        'prisma/schema.prisma',
        '--exit-code',
      ],
      {
        cwd: require('node:path').resolve(__dirname, '..'),
        env: { ...process.env, DATABASE_URL: databaseUrl },
        encoding: 'utf8',
      },
    );
    assert.match(diff, /No difference detected/);
  } finally {
    await prisma.$executeRawUnsafe(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
    await prisma.$disconnect();
  }
});
