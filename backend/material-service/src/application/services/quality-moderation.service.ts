import { Injectable } from '@nestjs/common';
import { Prisma } from '.prisma/material-client';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { Decision } from '../../infrastructure/moderation/decision';
import { ServiceContext, digest, fault } from '../../infrastructure/moderation/service-assertion';
const select = {
  id: true,
  uploaderId: true,
  title: true,
  description: true,
  externalLink: true,
  status: true,
  verified: true,
  revision: true,
  createdAt: true,
  updatedAt: true,
  materialType: { select: { name: true } },
  versions: {
    orderBy: { versionNumber: 'desc' as const },
    select: {
      id: true,
      versionNumber: true,
      originalFilename: true,
      mimeType: true,
      fileSize: true,
      createdAt: true,
    },
  },
};
type SnapshotRow = Prisma.MaterialGetPayload<{ select: typeof select }>;
function snapshot(m: SnapshotRow) {
  return {
    ...m,
    materialType: m.materialType.name,
    currentVersionId: m.versions[0]?.id ?? null,
    createdAt: m.createdAt.toISOString(),
    updatedAt: m.updatedAt.toISOString(),
    versions: m.versions.map((v) => ({
      ...v,
      fileSize: v.fileSize.toString(),
      createdAt: v.createdAt.toISOString(),
    })),
  };
}
@Injectable()
export class QualityModerationService {
  constructor(private readonly prisma: PrismaService) {}
  async read(id: string) {
    return this.prisma.$transaction(
      async (tx) => {
        const m = await tx.material.findUnique({ where: { id }, select });
        if (!m) throw fault(404, 'NOT_FOUND', 'Material no encontrado.');
        return snapshot(m);
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }
  async list(q: {
    page: number;
    pageSize: number;
    status: 'PENDING_REVIEW' | 'PUBLISHED' | 'REJECTED' | 'RETIRED';
  }) {
    return this.prisma.$transaction(
      async (tx) => {
        const where = { status: q.status };
        const rows = await tx.material.findMany({
          where,
          select,
          skip: (q.page - 1) * q.pageSize,
          take: q.pageSize,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        });
        return {
          items: rows.map(snapshot),
          page: q.page,
          pageSize: q.pageSize,
          total: await tx.material.count({ where }),
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }
  async apply(materialId: string, operationId: string, body: Decision, actor: ServiceContext) {
    const issuerService = 'quality-service';
    const fingerprint = digest({
      materialId,
      body,
      actorId: actor.actorId,
      actorRole: actor.actorRole,
      authorizedAt: actor.authorizedAt,
    });
    return this.prisma.$transaction(
      async (tx) => {
        // Serialize the operation even when no receipt/material exists yet.
        const lockKey = issuerService + ':' + operationId;
        await tx.$queryRaw`SELECT 1 FROM pg_advisory_xact_lock(hashtextextended(${lockKey},0))`;
        const existing = await tx.qualityDecisionReceipt.findUnique({
          where: { issuerService_operationId: { issuerService, operationId } },
        });
        if (existing) {
          if (existing.fingerprint !== fingerprint)
            throw fault(409, 'IDEMPOTENCY_CONFLICT', 'La operación tiene otro contenido.');
          return { status: existing.httpStatus, body: existing.response };
        }
        await tx.$queryRaw`SELECT id FROM materials WHERE id=${materialId}::uuid FOR UPDATE`;
        const material = await tx.material.findUnique({ where: { id: materialId } });
        let status = 200;
        let response: Prisma.InputJsonObject;
        const failed = (http: number, code: string, message: string) => {
          status = http;
          return { statusCode: http, code, message };
        };
        if (!material) response = failed(404, 'NOT_FOUND', 'Material no encontrado.');
        else if (material.uploaderId === actor.actorId)
          response = failed(403, 'SELF_REVIEW_FORBIDDEN', 'No se permite autorrevisión.');
        else if (material.revision !== body.expectedRevision)
          response = failed(409, 'STALE_REVISION', 'El material cambió.');
        else if (material.status !== 'PENDING_REVIEW')
          response = failed(409, 'INVALID_TRANSITION', 'El material no está pendiente.');
        else if (material.revision === 2147483647)
          response = failed(409, 'REVISION_EXHAUSTED', 'No se puede incrementar la revisión.');
        else {
          const updated = await tx.material.update({
            where: { id: materialId },
            data: {
              status: body.action === 'APPROVE' ? 'PUBLISHED' : 'REJECTED',
              verified: false,
              revision: { increment: 1 },
            },
          });
          response = {
            operationId,
            actorId: actor.actorId,
            result: {
              materialId,
              status: updated.status,
              verified: updated.verified,
              revision: updated.revision,
            },
            appliedAt: new Date().toISOString(),
          };
        }
        await tx.qualityDecisionReceipt.create({
          data: {
            issuerService,
            operationId,
            fingerprint,
            materialId,
            actorId: actor.actorId,
            httpStatus: status,
            response,
          },
        });
        return { status, body: response };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted },
    );
  }
  async receipt(operationId: string, actor: ServiceContext) {
    const row = await this.prisma.qualityDecisionReceipt.findUnique({
      where: { issuerService_operationId: { issuerService: 'quality-service', operationId } },
    });
    if (!row || row.httpStatus !== 200)
      throw fault(404, 'NOT_FOUND', 'No se observa un recibo aplicado.');
    if (row.actorId !== actor.actorId) throw fault(403, 'FORBIDDEN', 'Actor no coincidente.');
    return row.response;
  }
}
