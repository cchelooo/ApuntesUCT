import { Injectable, OnModuleInit, OnModuleDestroy, Logger, HttpException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../infrastructure/prisma/prisma.service';
import { MaterialClient } from '../infrastructure/moderation/material-client';
import { decision } from '../infrastructure/moderation/decision';
@Injectable()
export class ModerationWorker implements OnModuleInit, OnModuleDestroy {
  private timer?: ReturnType<typeof setInterval>;
  private running?: Promise<void>;
  private readonly logger = new Logger(ModerationWorker.name);
  constructor(
    private readonly prisma: PrismaService,
    private readonly material: MaterialClient,
  ) {}
  onModuleInit() {
    if (
      process.env.QUALITY_MODERATION_ENABLED === 'true' &&
      process.env.QUALITY_WORKER_ENABLED !== 'false'
    ) {
      this.timer = setInterval(() => {
        if (!this.running)
          this.running = this.tick()
            .catch(() => {
              this.logger.error('Fallo de entrega; se conserva el trabajo pendiente.');
            })
            .finally(() => {
              this.running = undefined;
            });
      }, 1000);
      this.timer.unref();
    }
  }
  async onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    await this.running;
  }
  async tick(): Promise<void> {
    const now = new Date();
    const candidate = await this.prisma.moderationOutbox.findFirst({
      where: {
        completedAt: null,
        nextAttemptAt: { lte: now },
        OR: [{ leaseUntil: null }, { leaseUntil: { lte: now } }],
      },
      orderBy: [{ nextAttemptAt: 'asc' }, { operationId: 'asc' }],
    });
    if (!candidate) return;
    const leaseToken = randomUUID();
    const claimed = await this.prisma.moderationOutbox.updateMany({
      where: {
        operationId: candidate.operationId,
        completedAt: null,
        OR: [{ leaseUntil: null }, { leaseUntil: { lte: now } }],
      },
      data: { leaseUntil: new Date(now.getTime() + 30000), leaseToken, attempts: { increment: 1 } },
    });
    if (claimed.count !== 1) return;
    const op = await this.prisma.moderationOperation.findUniqueOrThrow({
      where: { id: candidate.operationId },
    });
    try {
      const body = decision({
        action: op.action,
        expectedRevision: op.expectedRevision,
        ...(op.reason === null ? {} : { reason: op.reason }),
      });
      const receipt = await this.material.apply(
        op.id,
        op.materialId,
        body,
        { id: op.actorId, role: op.actorRole, authorizedAt: op.authorizedAt.toISOString() },
        randomUUID(),
      );
      await this.prisma.$transaction(async (tx) => {
        const owned = await tx.moderationOutbox.updateMany({
          where: { operationId: op.id, leaseToken, completedAt: null },
          data: { completedAt: new Date(), leaseUntil: null, leaseToken: null },
        });
        if (owned.count === 1)
          await tx.moderationOperation.update({
            where: { id: op.id },
            data: { state: 'APPLIED', result: receipt.result },
          });
      });
    } catch (e) {
      const status = e instanceof HttpException ? e.getStatus() : 0;
      const response = e instanceof HttpException ? e.getResponse() : null;
      const failure =
        response && typeof response === 'object' ? (response as { code?: string }) : {};
      // Only explicit, validated business failures are terminal. Service credential errors stay pending.
      const terminal =
        (status === 403 && failure.code === 'SELF_REVIEW_FORBIDDEN') ||
        (status === 404 && failure.code === 'NOT_FOUND') ||
        (status === 409 &&
          [
            'STALE_REVISION',
            'INVALID_TRANSITION',
            'IDEMPOTENCY_CONFLICT',
            'REVISION_EXHAUSTED',
          ].includes(failure.code ?? ''));
      if (terminal) {
        await this.prisma.$transaction(async (tx) => {
          const owned = await tx.moderationOutbox.updateMany({
            where: { operationId: op.id, leaseToken, completedAt: null },
            data: { completedAt: new Date(), leaseUntil: null, leaseToken: null },
          });
          if (owned.count === 1)
            await tx.moderationOperation.update({
              where: { id: op.id },
              data: {
                state: 'FAILED',
                failure: {
                  statusCode: status,
                  code: failure.code!,
                  message: 'Material rechazó definitivamente la aplicación.',
                },
              },
            });
        });
      } else {
        await this.prisma.moderationOutbox.updateMany({
          where: { operationId: op.id, leaseToken, completedAt: null },
          data: {
            leaseToken: null,
            leaseUntil: null,
            nextAttemptAt: new Date(
              Date.now() + Math.min(60000, 1000 * 2 ** Math.min(candidate.attempts, 6)),
            ),
          },
        });
        this.logger.warn({
          event: 'moderation.delivery.retry',
          operationId: op.id,
          statusCode: status || null,
        });
      }
    }
  }
}
