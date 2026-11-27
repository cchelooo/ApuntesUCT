import { Injectable, HttpException } from '@nestjs/common';
import { Readable } from 'node:stream';
import { Actor, serviceToken, fault, uuid } from './service-assertion';
import { Decision } from './decision';
export type Snapshot = {
  id: string;
  uploaderId: string;
  revision: number;
  status: string;
  verified: boolean;
  title: string;
  description: string | null;
  materialType: string;
  externalLink: string | null;
  currentVersionId: string | null;
  versions: Array<{
    id: string;
    versionNumber: number;
    originalFilename: string;
    mimeType: string;
    fileSize: string;
    createdAt: string;
  }>;
  createdAt: string;
  updatedAt: string;
};
const integer = (x: unknown, min = 0) =>
  Number.isInteger(x) && Number(x) >= min && Number(x) <= 2147483647;
const date = (x: unknown) => typeof x === 'string' && Number.isFinite(Date.parse(x));
export function parseSnapshot(value: unknown): Snapshot {
  const m = value as Snapshot;
  if (
    !m ||
    !uuid(m.id) ||
    !uuid(m.uploaderId) ||
    !integer(m.revision, 1) ||
    !['PENDING_REVIEW', 'PUBLISHED', 'REJECTED', 'RETIRED'].includes(m.status) ||
    typeof m.verified !== 'boolean' ||
    typeof m.title !== 'string' ||
    typeof m.materialType !== 'string' ||
    !(m.description === null || typeof m.description === 'string') ||
    !(m.externalLink === null || typeof m.externalLink === 'string') ||
    !(m.currentVersionId === null || uuid(m.currentVersionId)) ||
    !Array.isArray(m.versions) ||
    !date(m.createdAt) ||
    !date(m.updatedAt)
  )
    throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Snapshot inválido.');
  const versions = m.versions.map((v) => {
    if (
      !v ||
      !uuid(v.id) ||
      !integer(v.versionNumber, 1) ||
      typeof v.originalFilename !== 'string' ||
      typeof v.mimeType !== 'string' ||
      typeof v.fileSize !== 'string' ||
      !/^\d+$/.test(v.fileSize) ||
      !date(v.createdAt)
    )
      throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Versión inválida.');
    return {
      id: v.id,
      versionNumber: v.versionNumber,
      originalFilename: v.originalFilename,
      mimeType: v.mimeType,
      fileSize: v.fileSize,
      createdAt: v.createdAt,
    };
  });
  if (m.currentVersionId !== null && !versions.some((v) => v.id === m.currentVersionId))
    throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Versión actual inconsistente.');
  return {
    id: m.id,
    uploaderId: m.uploaderId,
    revision: m.revision,
    status: m.status,
    verified: m.verified,
    title: m.title,
    description: m.description,
    materialType: m.materialType,
    externalLink: m.externalLink,
    currentVersionId: m.currentVersionId,
    versions,
    createdAt: m.createdAt,
    updatedAt: m.updatedAt,
  };
}
export type Receipt = {
  operationId: string;
  actorId: string;
  result: { materialId: string; status: string; verified: boolean; revision: number };
  appliedAt: string;
};
export function parseReceipt(
  value: unknown,
  id: string,
  materialId: string,
  actorId: string,
  body: Decision,
): Receipt {
  const r = value as Receipt;
  if (
    !r ||
    r.operationId !== id ||
    r.actorId !== actorId ||
    !r.result ||
    r.result.materialId !== materialId ||
    r.result.status !== (body.action === 'APPROVE' ? 'PUBLISHED' : 'REJECTED') ||
    r.result.verified !== false ||
    !integer(r.result.revision, 1) ||
    r.result.revision !== body.expectedRevision + 1 ||
    !date(r.appliedAt)
  )
    throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Recibo inconsistente.');
  return {
    operationId: r.operationId,
    actorId: r.actorId,
    appliedAt: r.appliedAt,
    result: {
      materialId: r.result.materialId,
      status: r.result.status,
      verified: false,
      revision: r.result.revision,
    },
  };
}
@Injectable()
export class MaterialClient {
  private async call(
    resource: string,
    scope: string,
    actor: Actor,
    requestId: string,
    method = 'GET',
    body: unknown = null,
    operationId?: string,
  ) {
    const key = process.env.QUALITY_SERVICE_PRIVATE_KEY;
    const base = process.env.MATERIAL_INTERNAL_URL;
    if (!key || !base)
      throw fault(503, 'DEPENDENCY_UNAVAILABLE', 'Integración interna no configurada.');
    if (process.env.NODE_ENV === 'production' && !base.startsWith('https://'))
      throw fault(503, 'DEPENDENCY_UNAVAILABLE', 'Transporte interno no configurado.');
    try {
      const response = await fetch(new URL(resource, base), {
        method,
        redirect: 'error',
        signal: AbortSignal.timeout(4000),
        headers: {
          Authorization:
            'Bearer ' +
            serviceToken(key, 'material-service', scope, resource, actor, body, operationId),
          'X-Request-Id': requestId,
          ...(body === null ? {} : { 'Content-Type': 'application/json' }),
        },
        ...(body === null ? {} : { body: JSON.stringify(body) }),
      });
      if (!response.ok) {
        let data: Record<string, unknown>;
        try {
          data = (await response.json()) as Record<string, unknown>;
        } catch {
          throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Error interno ilegible.');
        }
        const allowed: Record<string, number> = {
          VALIDATION_ERROR: 400,
          UNAUTHENTICATED: 401,
          SERVICE_UNAUTHENTICATED: 401,
          SERVICE_FORBIDDEN: 403,
          FORBIDDEN: 403,
          SELF_REVIEW_FORBIDDEN: 403,
          NOT_FOUND: 404,
          STALE_REVISION: 409,
          INVALID_TRANSITION: 409,
          IDEMPOTENCY_CONFLICT: 409,
          REVISION_EXHAUSTED: 409,
          DEPENDENCY_UNAVAILABLE: 503,
        };
        if (
          typeof data.code !== 'string' ||
          allowed[data.code] !== response.status ||
          data.statusCode !== response.status ||
          !uuid(data.requestId)
        )
          throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Error interno inconsistente.');
        if (
          response.status === 401 ||
          (response.status === 403 && data.code !== 'SELF_REVIEW_FORBIDDEN')
        )
          throw fault(503, 'DEPENDENCY_UNAVAILABLE', 'Autorización de servicio no disponible.');
        throw fault(response.status, data.code, 'Material no pudo completar la operación.');
      }
      return response;
    } catch (e) {
      if (e instanceof HttpException) throw e;
      throw fault(503, 'DEPENDENCY_UNAVAILABLE', 'Material no disponible.');
    }
  }
  private async json(
    resource: string,
    scope: string,
    actor: Actor,
    requestId: string,
    method = 'GET',
    body: unknown = null,
    operationId?: string,
  ): Promise<unknown> {
    const r = await this.call(resource, scope, actor, requestId, method, body, operationId);
    try {
      return await r.json();
    } catch {
      throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Respuesta interna ilegible.');
    }
  }
  async read(id: string, actor: Actor, requestId: string) {
    id = id.toLowerCase();
    const m = parseSnapshot(
      await this.json(
        '/internal/v1/quality/materials/' + id,
        'material:review:read',
        actor,
        requestId,
      ),
    );
    if (m.id !== id) throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Material inconsistente.');
    return m;
  }
  async list(
    q: { page: number; pageSize: number; status: string },
    actor: Actor,
    requestId: string,
  ) {
    const resource =
      '/internal/v1/quality/materials?' +
      new URLSearchParams({
        page: String(q.page),
        pageSize: String(q.pageSize),
        status: q.status,
      }).toString();
    const p = (await this.json(resource, 'material:review:read', actor, requestId)) as {
      items: unknown[];
      page: number;
      pageSize: number;
      total: number;
    };
    if (
      !p ||
      !Array.isArray(p.items) ||
      p.items.length > q.pageSize ||
      p.page !== q.page ||
      p.pageSize !== q.pageSize ||
      !integer(p.total)
    )
      throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Página inválida.');
    return {
      items: p.items.map(parseSnapshot),
      page: p.page,
      pageSize: p.pageSize,
      total: p.total,
    };
  }
  async apply(id: string, materialId: string, body: Decision, actor: Actor, requestId: string) {
    return parseReceipt(
      await this.json(
        '/internal/v1/quality/materials/' + materialId + '/decisions/' + id,
        'material:quality:apply',
        actor,
        requestId,
        'PUT',
        body,
        id,
      ),
      id,
      materialId,
      actor.id,
      body,
    );
  }
  async download(id: string, version: string, actor: Actor, requestId: string) {
    const r = await this.call(
      '/internal/v1/quality/materials/' + id + '/versions/' + version + '/download',
      'material:review:read',
      actor,
      requestId,
    );
    const mime = r.headers.get('content-type'),
      length = r.headers.get('content-length'),
      disposition = r.headers.get('content-disposition');
    if (
      !r.body ||
      !mime ||
      !length ||
      !/^\d+$/.test(length) ||
      !Number.isSafeInteger(Number(length)) ||
      !disposition?.startsWith('attachment;')
    ) {
      await r.body?.cancel();
      throw fault(502, 'DEPENDENCY_INVALID_RESPONSE', 'Archivo inválido.');
    }
    return { stream: Readable.fromWeb(r.body as never), mime, length: Number(length), disposition };
  }
}
