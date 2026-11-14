import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { PasswordHasher } from '../../infrastructure/security/password-hasher';
import { PasswordRecoveryDelivery } from '../../infrastructure/notifications/password-recovery-delivery';

export const RECOVERY_MESSAGE =
  'Si el correo corresponde a una cuenta habilitada, recibirás instrucciones para recuperar tu contraseña.';
export const RECOVERY_TTL_MS = 15 * 60 * 1000;

@Injectable()
export class PasswordRecoveryService {
  private readonly logger = new Logger(PasswordRecoveryService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordHasher,
    private readonly delivery: PasswordRecoveryDelivery,
  ) {}

  request(email: string) {
    // Respond before looking up the account or contacting the delivery channel.
    setImmediate(() => {
      void this.issue(email).catch(() => {
        // Never log recipient, token, provider response or credentials.
        this.logger.error('No se pudo procesar una solicitud de recuperación');
      });
    });
    return { message: RECOVERY_MESSAGE };
  }

  async issue(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { email: email.trim().toLowerCase() },
    });
    if (!user?.active) return;
    const token = randomBytes(32).toString('hex');
    const tokenHash = this.digest(token);
    const expiresAt = new Date(Date.now() + RECOVERY_TTL_MS);
    const saved = await this.prisma.passwordResetToken.create({
      data: { userId: user.id, tokenHash, expiresAt },
    });
    try {
      await this.delivery.send(user.email, token, expiresAt);
    } catch (error) {
      await this.prisma.passwordResetToken.delete({ where: { id: saved.id } });
      throw error;
    }
  }

  async reset(token: string, password: string) {
    const tokenHash = this.digest(token);
    const candidate = await this.prisma.passwordResetToken.findUnique({
      where: { tokenHash },
    });
    if (!candidate || candidate.usedAt || candidate.expiresAt <= new Date()) {
      throw this.invalidToken();
    }
    const passwordHash = await this.passwords.hash(password);
    await this.prisma.$transaction(async (tx) => {
      // Serialize resets for this account, including requests with different tokens.
      const user = await tx.user.updateMany({
        where: { id: candidate.userId, active: true },
        data: { passwordHash },
      });
      if (user.count !== 1) throw this.invalidToken();
      const now = new Date();
      const consumed = await tx.passwordResetToken.updateMany({
        where: { id: candidate.id, usedAt: null, expiresAt: { gt: now } },
        data: { usedAt: now },
      });
      // A competing reset or expiration rolls back the password update too.
      if (consumed.count !== 1) throw this.invalidToken();
      await tx.passwordResetToken.updateMany({
        where: { userId: candidate.userId, usedAt: null },
        data: { usedAt: now },
      });
      await tx.refreshToken.updateMany({
        where: { userId: candidate.userId, revokedAt: null },
        data: { revokedAt: now },
      });
    });
    return { message: 'Contraseña restablecida correctamente.' };
  }

  private digest(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private invalidToken() {
    return new BadRequestException('El token es inválido o ha expirado.');
  }
}
