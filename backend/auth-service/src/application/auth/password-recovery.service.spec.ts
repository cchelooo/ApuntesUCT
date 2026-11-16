import { BadRequestException, Logger } from '@nestjs/common';
import { createHash } from 'node:crypto';
import {
  PasswordRecoveryService,
  RECOVERY_MESSAGE,
  RECOVERY_TTL_MS,
} from './password-recovery.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PasswordHasher } from '../../infrastructure/security/password-hasher';
import { PasswordRecoveryDelivery } from '../../infrastructure/notifications/password-recovery-delivery';

describe('PasswordRecoveryService', () => {
  const token = 'a'.repeat(64);
  const user = { id: 'user-id', email: 'user@uct.cl', active: true };
  const candidate = () => ({
    id: 'reset-id',
    userId: user.id,
    usedAt: null,
    expiresAt: new Date(Date.now() + 60000),
  });
  const prisma = {
    user: { findUnique: jest.fn(), updateMany: jest.fn() },
    passwordResetToken: {
      create: jest.fn(),
      delete: jest.fn(),
      findUnique: jest.fn(),
      updateMany: jest.fn(),
    },
    refreshToken: { updateMany: jest.fn() },
    $transaction: jest.fn(),
  };
  const passwords = { hash: jest.fn() };
  const delivery = { send: jest.fn() };
  const service = new PasswordRecoveryService(
    prisma as unknown as PrismaService,
    passwords as unknown as PasswordHasher,
    delivery as unknown as PasswordRecoveryDelivery,
  );

  beforeEach(() => {
    jest.resetAllMocks();
    prisma.user.findUnique.mockResolvedValue(user);
    prisma.user.updateMany.mockResolvedValue({ count: 1 });
    prisma.passwordResetToken.create.mockResolvedValue({ id: 'reset-id' });
    prisma.passwordResetToken.findUnique.mockResolvedValue(candidate());
    prisma.passwordResetToken.updateMany.mockResolvedValue({ count: 1 });
    passwords.hash.mockResolvedValue('secure-hash');
    prisma.$transaction.mockImplementation(
      (fn: (tx: typeof prisma) => Promise<void>) => fn(prisma),
    );
  });

  it('persiste solo SHA-256 y entrega 256 bits por el canal privado, con expiración de 15 minutos', async () => {
    const before = Date.now();
    await service.issue(' USER@UCT.CL ');
    const [email, delivered, expiresAt] = delivery.send.mock.calls[0] as [
      string,
      string,
      Date,
    ];
    expect(email).toBe(user.email);
    expect(delivered).toMatch(/^[a-f0-9]{64}$/);
    expect(expiresAt.getTime()).toBeGreaterThanOrEqual(
      before + RECOVERY_TTL_MS,
    );
    expect(expiresAt.getTime()).toBeLessThanOrEqual(
      Date.now() + RECOVERY_TTL_MS,
    );
    expect(prisma.passwordResetToken.create).toHaveBeenCalledWith({
      data: {
        userId: user.id,
        tokenHash: createHash('sha256').update(delivered).digest('hex'),
        expiresAt,
      },
    });
    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: user.email },
    });
  });

  it.each([null, { ...user, active: false }])(
    'no entrega tokens a cuentas ausentes o inactivas',
    async (account) => {
      prisma.user.findUnique.mockResolvedValue(account);
      await service.issue(user.email);
      expect(delivery.send).not.toHaveBeenCalled();
      expect(prisma.passwordResetToken.create).not.toHaveBeenCalled();
    },
  );

  it('elimina el token cuando falla la entrega', async () => {
    delivery.send.mockRejectedValue(new Error('private provider response'));
    await expect(service.issue(user.email)).rejects.toThrow();
    expect(prisma.passwordResetToken.delete).toHaveBeenCalledWith({
      where: { id: 'reset-id' },
    });
  });

  it('responde antes de consultar la cuenta y oculta fallos internos', async () => {
    const log = jest
      .spyOn(Logger.prototype, 'error')
      .mockImplementation(() => undefined);
    prisma.user.findUnique.mockRejectedValue(new Error('secret'));
    expect(service.request(user.email)).toEqual({ message: RECOVERY_MESSAGE });
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
    await new Promise<void>((resolve) => setImmediate(resolve));
    expect(log).toHaveBeenCalledWith(
      'No se pudo procesar una solicitud de recuperación',
    );
    log.mockRestore();
  });

  it.each([
    null,
    { ...candidate(), expiresAt: new Date(0) },
    { ...candidate(), usedAt: new Date() },
  ])('rechaza token inválido, vencido o reutilizado', async (value) => {
    prisma.passwordResetToken.findUnique.mockResolvedValue(value);
    await expect(service.reset(token, 'new password')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(passwords.hash).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('actualiza el hash, consume el token y revoca los demás tokens en la misma transacción', async () => {
    await service.reset(token, ' new password ');
    expect(passwords.hash).toHaveBeenCalledWith(' new password ');
    expect(prisma.user.updateMany).toHaveBeenCalledWith({
      where: { id: user.id, active: true },
      data: { passwordHash: 'secure-hash' },
    });
    expect(prisma.passwordResetToken.updateMany).toHaveBeenNthCalledWith(1, {
      where: {
        id: 'reset-id',
        usedAt: null,
        expiresAt: { gt: expect.any(Date) as Date },
      },
      data: { usedAt: expect.any(Date) as Date },
    });
    expect(prisma.passwordResetToken.updateMany).toHaveBeenCalledTimes(2);
    expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({
      where: { userId: user.id, revokedAt: null },
      data: { revokedAt: expect.any(Date) as Date },
    });
  });

  it('aborta la transacción si otro proceso consumió el token', async () => {
    prisma.passwordResetToken.updateMany.mockResolvedValueOnce({ count: 0 });
    await expect(service.reset(token, 'new password')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.refreshToken.updateMany).not.toHaveBeenCalled();
  });

  it('rechaza cuentas desactivadas sin consumir el token', async () => {
    prisma.user.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.reset(token, 'new password')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.passwordResetToken.updateMany).not.toHaveBeenCalled();
  });
});
