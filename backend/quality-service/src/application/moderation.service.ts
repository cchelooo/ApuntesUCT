import { Injectable, HttpException } from '@nestjs/common';
import { Prisma, ModerationOperation } from '.prisma/quality-client';
import { PrismaService } from '../infrastructure/prisma/prisma.service';
import { MaterialClient } from '../infrastructure/moderation/material-client';
import { Decision } from '../infrastructure/moderation/decision';
import { Actor, digest, fault } from '../infrastructure/moderation/service-assertion';
export function operationDto(o: ModerationOperation) {
  return {
    id: o.id,
    materialId: o.materialId,
    actorId: o.actorId,
    action: o.action,
    reason: o.reason,
    expectedRevision: o.expectedRevision,
    state: o.state,
    result: o.result,
    failure: o.failure,
    createdAt: o.createdAt.toISOString(),
    updatedAt: o.updatedAt.toISOString(),
  };
}
@Injectable()
export class ModerationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly material: MaterialClient,
  ) {}
  async get(id: string) {
    const o = await this.prisma.moderationOperation.findUnique({ where: { id } });
    if (!o) throw fault(404, 'NOT_FOUND', 'Operación no encontrada.');
    return operationDto(o);
  }
  async accept(materialId: string, key: string, body: Decision, actor: Actor, requestId: string) {
    const operationFamily = 'moderation.decisions';
    const where = {
      actorId_operationFamily_idempotencyKey: {
        actorId: actor.id,
        operationFamily,
        idempotencyKey: key,
      },
    };
    const fingerprint = digest({
      materialId,
      action: body.action,
      expectedRevision: body.expectedRevision,
      reason: body.reason ?? null,
    });
    const replay = (existing: ModerationOperation) => {
      if (existing.fingerprint !== fingerprint)
        throw fault(409, 'IDEMPOTENCY_CONFLICT', 'La clave ya identifica otra solicitud.');
      return {
        status: existing.state === 'PENDING_APPLICATION' ? 202 : 200,
        operation: operationDto(existing),
      };
    };
    const previous = await this.prisma.moderationOperation.findUnique({ where });
    if (previous) return replay(previous);
    let snapshot;
    try {
      snapshot = await this.material.read(materialId, actor, requestId);
      if (snapshot.uploaderId === actor.id)
        throw fault(403, 'SELF_REVIEW_FORBIDDEN', 'No se permite autorrevisión.');
      if (snapshot.revision !== body.expectedRevision)
        throw fault(409, 'STALE_REVISION', 'El material cambió.');
      if (snapshot.status !== 'PENDING_REVIEW')
        throw fault(409, 'INVALID_TRANSITION', 'El material no está pendiente.');
    } catch (e) {
      const concurrent = await this.prisma.moderationOperation.findUnique({ where });
      if (concurrent) return replay(concurrent);
      if (
        e instanceof HttpException &&
        [401, 403].includes(e.getStatus()) &&
        (e.getResponse() as { code?: string }).code !== 'SELF_REVIEW_FORBIDDEN'
      )
        throw fault(503, 'DEPENDENCY_UNAVAILABLE', 'Autorización interna no disponible.');
      throw e;
    }
    try {
      const saved = await this.prisma.$transaction(async (tx) => {
        const operation = await tx.moderationOperation.create({
          data: {
            materialId,
            actorId: actor.id,
            actorRole: actor.role,
            authorizedAt: new Date(actor.authorizedAt),
            operationFamily,
            idempotencyKey: key,
            fingerprint,
            action: body.action,
            reason: body.reason ?? null,
            expectedRevision: body.expectedRevision,
            snapshot: snapshot,
          },
        });
        await tx.review.create({
          data: {
            materialId,
            materialVersionId: snapshot.currentVersionId,
            userId: actor.id,
            purpose: 'MODERATION',
            decision: body.action === 'APPROVE' ? 'ACCEPT' : 'REJECT',
            comment: body.reason ?? null,
            operationId: operation.id,
          },
        });
        await tx.moderationOutbox.create({ data: { operationId: operation.id } });
        return operation;
      });
      return { status: 202, operation: operationDto(saved) };
    } catch (e) {
      // A uniqueness race is resolved by the already committed operation, never by a second decision.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const concurrent = await this.prisma.moderationOperation.findUnique({ where });
        if (concurrent) return replay(concurrent);
      }
      throw fault(
        503,
        'DEPENDENCY_UNAVAILABLE',
        'No se pudo confirmar la aceptación. Reintente con la misma clave.',
      );
    }
  }
}
