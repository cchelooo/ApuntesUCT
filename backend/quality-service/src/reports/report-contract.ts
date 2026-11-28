import { HttpException } from '@nestjs/common';
import { isUUID, isISO8601 } from 'class-validator';
export const reasons = [
  'INAPPROPRIATE_CONTENT',
  'COPYRIGHT',
  'INCORRECT_INFORMATION',
  'BROKEN_RESOURCE',
  'OTHER',
] as const;
export const statuses = ['OPEN', 'IN_REVIEW', 'RESOLVED', 'DISMISSED'] as const;
export type Status = (typeof statuses)[number];
export type Actor = { id: string; role: 'STUDENT' | 'MODERATOR' | 'ADMIN' };
export function fail(status: number, code: string, message: string): never {
  throw new HttpException({ code, message }, status);
}
export function uuid(value: unknown): string {
  if (typeof value !== 'string' || !isUUID(value)) fail(400, 'VALIDATION_ERROR', 'UUID inválido.');
  return value.toLowerCase();
}
function object(value: unknown, keys: string[]): Record<string, unknown> {
  if (
    !value ||
    typeof value !== 'object' ||
    Array.isArray(value) ||
    Object.keys(value).some((k) => !keys.includes(k))
  )
    fail(400, 'VALIDATION_ERROR', 'Cuerpo o campos inválidos.');
  return value as Record<string, unknown>;
}
function text(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string') fail(400, 'VALIDATION_ERROR', 'Texto inválido.');
  const result = value.trim();
  if (result.length > 2000) fail(400, 'VALIDATION_ERROR', 'Máximo 2000 caracteres.');
  return result || null;
}
export function createInput(value: unknown) {
  const v = object(value, ['reason', 'details']);
  if (!reasons.includes(v.reason as (typeof reasons)[number]))
    fail(400, 'VALIDATION_ERROR', 'Motivo inválido.');
  const details = text(v.details);
  if (v.reason === 'OTHER' && !details) fail(400, 'VALIDATION_ERROR', 'OTHER requiere detalles.');
  return { reason: v.reason as string, details };
}
export function updateInput(value: unknown) {
  const v = object(value, ['status', 'expectedUpdatedAt', 'resolutionNote']);
  if (!['IN_REVIEW', 'RESOLVED', 'DISMISSED'].includes(v.status as string))
    fail(400, 'VALIDATION_ERROR', 'Estado inválido.');
  if (
    typeof v.expectedUpdatedAt !== 'string' ||
    !/T.*(?:Z|[+-]\d{2}:\d{2})$/i.test(v.expectedUpdatedAt) ||
    !isISO8601(v.expectedUpdatedAt, { strict: true }) ||
    !Number.isFinite(Date.parse(v.expectedUpdatedAt))
  )
    fail(400, 'VALIDATION_ERROR', 'expectedUpdatedAt inválido.');
  const resolutionNote = text(v.resolutionNote);
  if (Object.prototype.hasOwnProperty.call(v, 'resolutionNote') && !resolutionNote)
    fail(400, 'VALIDATION_ERROR', 'resolutionNote presente debe ser texto no vacío.');
  if (v.status !== 'IN_REVIEW' && !resolutionNote)
    fail(400, 'VALIDATION_ERROR', 'La resolución requiere una nota.');
  return {
    status: v.status as Status,
    expectedUpdatedAt: new Date(v.expectedUpdatedAt).toISOString(),
    resolutionNote,
  };
}
export function pageInput(query: Record<string, unknown>, admin = false) {
  if (
    Object.keys(query).some((k) => !['page', 'pageSize', ...(admin ? ['status'] : [])].includes(k))
  )
    fail(400, 'VALIDATION_ERROR', 'Parámetro desconocido.');
  const integer = (v: unknown, d: number, max: number) => {
    if (v === undefined) return d;
    if (typeof v !== 'string' || !/^\d+$/.test(v))
      fail(400, 'VALIDATION_ERROR', 'Paginación inválida.');
    const n = Number(v);
    if (!Number.isSafeInteger(n) || n < 1 || n > max)
      fail(400, 'VALIDATION_ERROR', 'Paginación fuera de rango.');
    return n;
  };
  const page = integer(query.page, 1, 2147483647),
    pageSize = integer(query.pageSize, 20, 100);
  if ((page - 1) * pageSize > 2147483647) fail(400, 'VALIDATION_ERROR', 'Offset excesivo.');
  if (query.status !== undefined && !statuses.includes(query.status as Status))
    fail(400, 'VALIDATION_ERROR', 'Estado inválido.');
  return { page, pageSize, status: query.status as Status | undefined };
}
export function moderator(actor: Actor) {
  if (actor.role !== 'MODERATOR' && actor.role !== 'ADMIN')
    fail(403, 'FORBIDDEN', 'Requiere MODERATOR o ADMIN.');
}
