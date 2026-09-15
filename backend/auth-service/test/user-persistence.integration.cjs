const { randomUUID } = require('node:crypto');
const assert = require('node:assert/strict');
const { test, after } = require('node:test');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();
const rollback = new Error('Rollback intentional de los datos de prueba');
const userData = () => ({
  name: 'Prueba de persistencia',
  email: `issue52-${randomUUID()}@alu.uct.cl`,
  passwordHash: 'hash-sintetico-solo-para-prueba',
});

after(() => prisma.$disconnect());

test('crea, consulta y actualiza usuarios; elimina sus tokens en cascada', async () => {
  await assert.rejects(
    prisma.$transaction(async (tx) => {
      const user = await tx.user.create({ data: userData() });
      assert.match(
        user.id,
        /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
      );
      assert.equal(user.role, 'STUDENT');
      assert.equal(user.active, true);
      assert.ok(user.createdAt instanceof Date);
      assert.ok(user.updatedAt instanceof Date);
      assert.equal(
        (await tx.user.findUnique({ where: { email: user.email } })).id,
        user.id,
      );

      const token = await tx.refreshToken.create({
        data: {
          tokenHash: randomUUID(),
          userId: user.id,
          expiresAt: new Date(Date.now() + 60_000),
        },
      });
      const types = await tx.$queryRaw`
        SELECT pg_typeof(u.id)::text AS id_type, pg_typeof(t.user_id)::text AS reference_type
        FROM users u JOIN refresh_tokens t ON t.user_id = u.id
        WHERE u.id = ${user.id}::uuid`;
      assert.deepEqual(types, [{ id_type: 'uuid', reference_type: 'uuid' }]);

      // Set an older timestamp to check @updatedAt without timing-dependent sleeps.
      await tx.$executeRaw`UPDATE users SET updated_at = TIMESTAMP '2000-01-01' WHERE id = ${user.id}::uuid`;
      const updated = await tx.user.update({
        where: { id: user.id },
        data: { active: false },
      });
      assert.equal(updated.active, false);
      assert.ok(updated.updatedAt > new Date('2000-01-01T00:00:00Z'));
      assert.equal(
        await tx.refreshToken.count({ where: { userId: user.id } }),
        1,
      );
      await tx.user.delete({ where: { id: user.id } });
      assert.equal(
        await tx.refreshToken.findUnique({ where: { id: token.id } }),
        null,
      );
      throw rollback;
    }),
    (error) => error === rollback,
  );
});

test('rechaza correos duplicados', async () => {
  await assert.rejects(
    prisma.$transaction(async (tx) => {
      const data = userData();
      await tx.user.create({ data });
      await tx.user.create({ data });
      throw rollback;
    }),
    (error) => error.code === 'P2002',
  );
});

test('rechaza tokens que referencian usuarios inexistentes', async () => {
  await assert.rejects(
    prisma.$transaction(async (tx) => {
      await tx.refreshToken.create({
        data: {
          tokenHash: randomUUID(),
          userId: randomUUID(),
          expiresAt: new Date(),
        },
      });
      throw rollback;
    }),
    (error) => error.code === 'P2003',
  );
});
