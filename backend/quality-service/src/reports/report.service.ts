import { Injectable, HttpException } from '@nestjs/common';
import { Prisma, Report } from '.prisma/quality-client';
import { createHash } from 'node:crypto';
import { PrismaService } from '../infrastructure/prisma/prisma.service';
import { Actor, createInput, updateInput, pageInput, fail, moderator } from './report-contract';
import { ReportDependencies } from './report-dependencies';

function dto(r: Report) {
  return {
    id: r.id,
    materialId: r.materialId,
    userId: r.userId,
    reason: r.reason,
    details: r.details,
    status: r.status,
    resolutionNote: r.resolutionNote,
    createdAt: r.createdAt.toISOString(),
    updatedAt: r.updatedAt.toISOString(),
  };
}
@Injectable()
export class ReportService {
  constructor(
    private readonly db: PrismaService,
    private readonly deps: ReportDependencies,
  ) {}
  private async lock(tx: Prisma.TransactionClient, key: string) {
    await tx.$queryRaw`SELECT 1 FROM pg_advisory_xact_lock(hashtextextended(${key},0))`;
  }
  private async mutation(
    actor: Actor,
    family: string,
    key: string,
    input: unknown,
    action: (tx: Prisma.TransactionClient) => Promise<ReturnType<typeof dto>>,
  ) {
    const fingerprint = createHash('sha256').update(JSON.stringify(input)).digest('hex');
    try {
      return await this.db.$transaction(
        async (tx) => {
          await this.lock(tx, 'report-key:' + actor.id + ':' + family + ':' + key);
          const existing = await tx.reportMutation.findUnique({
            where: { actorId_family_key: { actorId: actor.id, family, key } },
          });
          if (existing) {
            if (existing.fingerprint !== fingerprint)
              fail(409, 'IDEMPOTENCY_CONFLICT', 'Clave utilizada con otra solicitud.');
            return { replay: true, body: existing.response };
          }
          const body = await action(tx);
          await tx.reportMutation.create({
            data: { actorId: actor.id, family, key, fingerprint, response: body },
          });
          return { replay: false, body };
        },
        { maxWait: 2500, timeout: 4500 },
      );
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')
        fail(409, 'REPORT_ALREADY_OPEN', 'Ya existe un reporte abierto.');
      throw error;
    }
  }
  async create(
    actor: Actor,
    materialId: string,
    key: string,
    input: ReturnType<typeof createInput>,
  ) {
    return this.mutation(actor, 'reports:create', key, { materialId, ...input }, async (tx) => {
      // La clave se resuelve antes de consultar la visibilidad actual en Material.
      await this.lock(tx, 'report-open:' + actor.id + ':' + materialId);
      const existing = await tx.report.findFirst({
        where: { materialId, userId: actor.id, status: { in: ['OPEN', 'IN_REVIEW'] } },
      });
      if (existing) fail(409, 'REPORT_ALREADY_OPEN', 'Ya existe un reporte abierto.');
      const materialUploaderId = await this.deps.publishedOwner(materialId);
      const report = await tx.report.create({
        data: { materialId, userId: actor.id, materialUploaderId, ...input },
      });
      await tx.reportHistory.create({
        data: {
          reportId: report.id,
          actorId: actor.id,
          status: 'OPEN',
          createdAt: report.createdAt,
        },
      });
      return dto(report);
    });
  }
  async get(actor: Actor, id: string) {
    const report = await this.db.report.findUnique({ where: { id } });
    if (!report || (actor.role === 'STUDENT' && report.userId !== actor.id))
      fail(404, 'NOT_FOUND', 'Reporte no encontrado.');
    return dto(report);
  }
  async list(actor: Actor, query: ReturnType<typeof pageInput>, admin: boolean) {
    if (admin) moderator(actor);
    const where: Prisma.ReportWhereInput = admin ? { status: query.status } : { userId: actor.id };
    const [items, total] = await this.db.$transaction(
      [
        this.db.report.findMany({
          where,
          skip: (query.page - 1) * query.pageSize,
          take: query.pageSize,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        }),
        this.db.report.count({ where }),
      ],
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
    return { items: items.map(dto), page: query.page, pageSize: query.pageSize, total };
  }
  async update(actor: Actor, id: string, key: string, input: ReturnType<typeof updateInput>) {
    moderator(actor);
    return this.mutation(actor, 'reports:update', key, { id, ...input }, async (tx) => {
      await tx.$queryRaw`SELECT id FROM reports WHERE id=${id}::uuid FOR UPDATE`;
      const report = await tx.report.findUnique({ where: { id } });
      if (!report) fail(404, 'NOT_FOUND', 'Reporte no encontrado.');
      if (report.userId === actor.id)
        fail(403, 'SELF_REVIEW_FORBIDDEN', 'No puede tramitar su propio reporte.');
      let owner = report.materialUploaderId;
      if (!owner) {
        // Registros legados: no inventar propietario ni permitir tramitar sin comprobarlo.
        try {
          owner = await this.deps.publishedOwner(report.materialId);
        } catch (error) {
          if (error instanceof HttpException && error.getStatus() === 404)
            fail(
              503,
              'DEPENDENCY_UNAVAILABLE',
              'Reporte legado sin autoría verificable; requiere conciliación.',
            );
          throw error;
        }
      }
      if (owner === actor.id)
        fail(403, 'SELF_REVIEW_FORBIDDEN', 'No puede tramitar reportes sobre material propio.');
      if (report.updatedAt.toISOString() !== input.expectedUpdatedAt)
        fail(409, 'STALE_REVISION', 'El reporte cambió. Consulte nuevamente.');
      const allowed =
        report.status === 'OPEN'
          ? ['IN_REVIEW', 'RESOLVED', 'DISMISSED']
          : report.status === 'IN_REVIEW'
            ? ['RESOLVED', 'DISMISSED']
            : [];
      if (!allowed.includes(input.status))
        fail(409, 'INVALID_TRANSITION', 'Transición no permitida.');
      const updatedAt = new Date(Math.max(Date.now(), report.updatedAt.getTime() + 1));
      const updated = await tx.report.update({
        where: { id },
        data: {
          status: input.status,
          resolutionNote: input.resolutionNote,
          materialUploaderId: owner,
          updatedAt,
        },
      });
      await tx.reportHistory.create({
        data: {
          reportId: id,
          actorId: actor.id,
          previousStatus: report.status,
          status: updated.status,
          resolutionNote: updated.resolutionNote,
          createdAt: updatedAt,
        },
      });
      return dto(updated);
    });
  }
}
