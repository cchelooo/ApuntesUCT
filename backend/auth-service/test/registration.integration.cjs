const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { test, after } = require('node:test');
const { PrismaClient } = require('.prisma/auth-client');
const {
  RegisterUserService,
} = require('../dist/src/application/auth/register-user.service');
const {
  PasswordHasher,
} = require('../dist/src/infrastructure/security/password-hasher');
const prisma = new PrismaClient();
const email = `issue440-${randomUUID()}@alu.uct.cl`;
const service = new RegisterUserService(prisma, new PasswordHasher());
after(async () => {
  await prisma.user.deleteMany({ where: { email } });
  await prisma.$disconnect();
});
test('registro concurrente persiste una sola cuenta y nunca retorna secretos', async () => {
  const input = {
    name: 'Registro real',
    email,
    password: ' contraseña segura ',
  };
  const results = await Promise.allSettled([
    service.register(input),
    service.register({ ...input, email: ` ${email.toUpperCase()} ` }),
  ]);
  const success = results.filter((r) => r.status === 'fulfilled');
  const failures = results.filter((r) => r.status === 'rejected');
  assert.equal(success.length, 1);
  assert.equal(failures.length, 1);
  assert.equal(failures[0].reason.getStatus(), 409);
  const saved = await prisma.user.findUniqueOrThrow({ where: { email } });
  assert.match(
    saved.passwordHash,
    /^scrypt\$131072\$8\$1\$[a-f0-9]{32}\$[a-f0-9]{128}$/,
  );
  assert.equal(saved.role, 'STUDENT');
  assert.equal(saved.active, true);
  assert.deepEqual(success[0].value, {
    user: {
      id: saved.id,
      name: input.name,
      email,
      role: 'STUDENT',
      active: true,
    },
  });
  for (const role of ['MODERATOR', 'ADMIN']) {
    await prisma.user.update({ where: { email }, data: { role } });
    assert.equal(
      (await prisma.user.findUniqueOrThrow({ where: { email } })).role,
      role,
    );
  }
  await assert.rejects(
    prisma.user.update({
      where: { email },
      data: { email: email.toUpperCase() },
    }),
  );
});
