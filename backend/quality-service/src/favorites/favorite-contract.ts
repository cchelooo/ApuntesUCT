import { HttpException } from '@nestjs/common';
import { isUUID } from 'class-validator';
export type FavoriteActor = { id: string; role: 'STUDENT' | 'MODERATOR' | 'ADMIN' };
export function fail(status: number, code: string, message: string): never {
  throw new HttpException({ code, message }, status);
}
export function materialId(value: unknown): string {
  if (typeof value !== 'string' || !isUUID(value))
    fail(400, 'VALIDATION_ERROR', 'materialId debe ser UUID.');
  return value.toLowerCase();
}
export function pageInput(query: Record<string, unknown>) {
  if (Object.keys(query).some((k) => !['page', 'pageSize'].includes(k)))
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
  return { page, pageSize };
}
/** No se admiten atribuciones de identidad ni campos de escritura en estas rutas. */
export function noPayload(
  body: unknown,
  query: Record<string, unknown>,
  contentLength?: string,
  transferEncoding?: string,
) {
  if (
    Object.keys(query).length ||
    (body !== undefined &&
      body !== null &&
      !(typeof body === 'object' && !Array.isArray(body) && Object.keys(body).length === 0)) ||
    (contentLength !== undefined && contentLength !== '0') ||
    transferEncoding
  )
    fail(400, 'VALIDATION_ERROR', 'Esta operación no admite cuerpo ni parámetros de consulta.');
}
