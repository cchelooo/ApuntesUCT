import { fault } from './service-assertion';
export type Decision = { action: 'APPROVE' | 'REJECT'; expectedRevision: number; reason?: string };
export function decision(body: unknown): Decision {
  if (!body || typeof body !== 'object' || Array.isArray(body))
    throw fault(400, 'VALIDATION_ERROR', 'Solicitud inválida.');
  const b = body as Record<string, unknown>;
  if (
    Object.keys(b).some((k) => !['action', 'expectedRevision', 'reason'].includes(k)) ||
    typeof b.action !== 'string' ||
    !['APPROVE', 'REJECT'].includes(b.action) ||
    !Number.isInteger(b.expectedRevision) ||
    Number(b.expectedRevision) < 1 ||
    Number(b.expectedRevision) > 2147483647
  )
    throw fault(
      400,
      'VALIDATION_ERROR',
      'Se requiere APPROVE/REJECT y expectedRevision entero positivo.',
    );
  if (
    b.reason !== undefined &&
    (typeof b.reason !== 'string' || !b.reason.trim() || b.reason.trim().length > 2000)
  )
    throw fault(400, 'VALIDATION_ERROR', 'Motivo inválido.');
  if (b.action === 'REJECT' && b.reason === undefined)
    throw fault(400, 'VALIDATION_ERROR', 'El rechazo exige un motivo.');
  return {
    action: b.action as Decision['action'],
    expectedRevision: b.expectedRevision as number,
    ...(typeof b.reason === 'string' ? { reason: b.reason.trim() } : {}),
  };
}
export function pageQuery(query: Record<string, unknown>) {
  if (Object.keys(query).some((k) => !['page', 'pageSize', 'status'].includes(k)))
    throw fault(400, 'VALIDATION_ERROR', 'Parámetro desconocido.');
  const integer = (key: string, fallback: number, max: number) => {
    const v = query[key];
    if (v === undefined) return fallback;
    if (typeof v !== 'string' || !/^\d+$/.test(v) || Number(v) < 1 || Number(v) > max)
      throw fault(400, 'VALIDATION_ERROR', 'Paginación inválida.');
    return Number(v);
  };
  const page = integer('page', 1, 2147483647),
    pageSize = integer('pageSize', 20, 100);
  const status = query.status ?? 'PENDING_REVIEW';
  if (
    typeof status !== 'string' ||
    !['PENDING_REVIEW', 'PUBLISHED', 'REJECTED', 'RETIRED'].includes(status) ||
    (page - 1) * pageSize > 2147483647
  )
    throw fault(400, 'VALIDATION_ERROR', 'Filtro o desplazamiento inválido.');
  return {
    page,
    pageSize,
    status: status as 'PENDING_REVIEW' | 'PUBLISHED' | 'REJECTED' | 'RETIRED',
  };
}
