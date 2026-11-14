const assert = require('node:assert/strict');
const {
  randomUUID,
  randomBytes,
  createHash,
  scryptSync,
} = require('node:crypto');
const { test, after } = require('node:test');
const { PrismaClient } = require('.prisma/auth-client');
const {
  PasswordRecoveryService,
} = require('../dist/src/application/auth/password-recovery.service');
const {
  PasswordHasher,
} = require('../dist/src/infrastructure/security/password-hasher');
const prisma = new PrismaClient();
const email = `issue442-${randomUUID()}@alu.uct.cl`;
const deliveries = [];
const service = new PasswordRecoveryService(prisma, new PasswordHasher(), {
  send: async (...args) => {
    deliveries.push(args);
  },
});
const digest = (token) => createHash('sha256').update(token).digest('hex');
after(async () => {
  await prisma.user.deleteMany({ where: { email } });
  await prisma.$disconnect();
});

test('recuperación real: hash seguro, concurrencia, revocación y rollback', async () => {
  const user = await prisma.user.create({
    data: { name: 'Recovery integration', email, passwordHash: 'old-hash' },
  });
  await prisma.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: randomUUID(),
      expiresAt: new Date(Date.now() + 60000),
    },
  });
  await service.issue(email);
  await service.issue(email);
  const [first, second] = deliveries.map((entry) => entry[1]);
  const savedToken = await prisma.passwordResetToken.findUniqueOrThrow({
    where: { tokenHash: digest(first) },
  });
  assert.notEqual(savedToken.tokenHash, first);
  assert.equal(savedToken.usedAt, null);
  const passwords = ['first new password', 'second new password'];
  const results = await Promise.allSettled([
    service.reset(first, passwords[0]),
    service.reset(second, passwords[1]),
  ]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  const failure = results.find((r) => r.status === 'rejected');
  assert.equal(failure.reason.getStatus(), 400);
  const updated = await prisma.user.findUniqueOrThrow({
    where: { id: user.id },
  });
  const [algorithm, n, r, p, salt, key] = updated.passwordHash.split('$');
  assert.equal(algorithm, 'scrypt');
  const winnerPassword =
    passwords[results.findIndex((result) => result.status === 'fulfilled')];
  assert.equal(
    scryptSync(winnerPassword, Buffer.from(salt, 'hex'), 64, {
      N: +n,
      r: +r,
      p: +p,
      maxmem: 256 * 1024 * 1024,
    }).toString('hex'),
    key,
  );
  assert.equal(
    await prisma.passwordResetToken.count({
      where: { userId: user.id, usedAt: null },
    }),
    0,
  );
  assert.equal(
    await prisma.refreshToken.count({
      where: { userId: user.id, revokedAt: null },
    }),
    0,
  );
  for (const token of [first, second, randomBytes(32).toString('hex')]) {
    await assert.rejects(
      service.reset(token, 'must not be saved'),
      (error) => error.getStatus() === 400,
    );
  }
  await service.issue(email);
  const expired = deliveries.at(-1)[1];
  await prisma.passwordResetToken.update({
    where: { tokenHash: digest(expired) },
    data: { expiresAt: new Date(0) },
  });
  await assert.rejects(
    service.reset(expired, 'must not be saved'),
    (error) => error.getStatus() === 400,
  );
  assert.equal(
    (await prisma.user.findUniqueOrThrow({ where: { id: user.id } }))
      .passwordHash,
    updated.passwordHash,
  );

  // Both contenders using the exact same token must also have one winner.
  await service.issue(email);
  const singleToken = deliveries.at(-1)[1];
  const sameTokenResults = await Promise.allSettled([
    service.reset(singleToken, 'same token password one'),
    service.reset(singleToken, 'same token password two'),
  ]);
  assert.equal(
    sameTokenResults.filter((r) => r.status === 'fulfilled').length,
    1,
  );
  assert.equal(
    sameTokenResults.find((r) => r.status === 'rejected').reason.getStatus(),
    400,
  );
});
