import { INestApplication, Logger } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { Request, Response, NextFunction } from 'express';
import { uuid } from './service-assertion';
export type AuditRequest = Request & {
  requestId?: string;
  identity?: { id: string; role: string };
  serviceContext?: { actorId: string; actorRole: string };
  auditRevision?: number;
  auditCount?: number;
  downloadAuthorized?: boolean;
};
export function installModerationAudit(app: INestApplication, service: string): void {
  const logger = new Logger('ModerationAccessAudit');
  app.use((req: AuditRequest, res: Response, next: NextFunction) => {
    const internal = req.path.startsWith('/internal/v1/quality');
    const quality = req.path.startsWith('/api/v1/quality');
    if (!internal && !quality) return next();
    // Correlation is not identity. Material accepts it only as an audit correlation ID.
    req.requestId =
      internal && uuid(req.headers['x-request-id']) ? req.headers['x-request-id'] : randomUUID();
    res.setHeader('X-Request-Id', req.requestId);
    res.setHeader('Cache-Control', 'no-store');
    const m = /\/materials(?:\/([^/]+))?(?:\/versions\/([^/]+)\/download)?$/.exec(req.path);
    if (req.method !== 'GET' || !m) return next();
    let done = false;
    const record = (aborted: boolean) => {
      if (done) return;
      done = true;
      const actor =
        req.identity ??
        (req.serviceContext
          ? { id: req.serviceContext.actorId, role: req.serviceContext.actorRole }
          : undefined);
      const status = res.statusCode;
      const outcome = aborted
        ? 'ABORTED'
        : status === 401 || status === 403
          ? 'DENIED'
          : status === 404
            ? 'NOT_FOUND'
            : status >= 400
              ? 'ERROR'
              : 'SUCCESS';
      const base = {
        eventId: randomUUID(),
        requestId: req.requestId,
        occurredAt: new Date().toISOString(),
        service,
        callerService: req.serviceContext ? 'quality-service' : null,
        actorId: actor?.id ?? null,
        actorRole: actor?.role ?? null,
        action: m[2]
          ? 'DOWNLOAD_PRIVATE_VERSION'
          : m[1]
            ? 'READ_PRIVATE_MATERIAL'
            : 'LIST_PRIVATE_MATERIALS',
        materialId: m[1] ?? null,
        versionId: m[2] ?? null,
        revision: req.auditRevision ?? null,
        httpStatus: res.headersSent ? status : null,
        outcome,
        reasonCode: aborted ? 'TRANSFER_ABORTED' : status >= 400 ? 'ACCESS_FAILED' : null,
      };
      if (m[2])
        logger.log({
          ...base,
          phase: 'AUTHORIZATION',
          outcome: req.downloadAuthorized ? 'SUCCESS' : outcome,
        });
      logger.log({
        ...base,
        phase: m[2] && req.downloadAuthorized ? 'TRANSFER_RESULT' : 'REQUEST_RESULT',
        ...(!m[1]
          ? {
              filters: {
                status: typeof req.query.status === 'string' ? req.query.status : 'PENDING_REVIEW',
              },
              page: req.query.page ?? 1,
              pageSize: req.query.pageSize ?? 20,
              returnedCount: req.auditCount ?? null,
            }
          : {}),
      });
    };
    res.once('finish', () => record(false));
    res.once('close', () => record(!res.writableFinished));
    next();
  });
}
