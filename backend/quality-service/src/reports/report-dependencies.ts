import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { isUUID } from 'class-validator';
import { Actor, fail } from './report-contract';

/** Sólo REST. El token se delega a Auth para consultar la identidad del propio portador. */
@Injectable()
export class ReportDependencies {
  constructor(private readonly config: ConfigService) {}
  private origin(key: string): string {
    const raw = this.config.get<string>(key);
    if (!raw) fail(503, 'DEPENDENCY_UNAVAILABLE', 'Integración no configurada.');
    let url: URL;
    try {
      url = new URL(raw);
    } catch {
      fail(503, 'DEPENDENCY_UNAVAILABLE', 'Origen inválido.');
    }
    if (
      !['http:', 'https:'].includes(url.protocol) ||
      url.username ||
      url.password ||
      url.search ||
      url.hash ||
      url.pathname !== '/' ||
      (this.config.get('NODE_ENV') === 'production' && url.protocol !== 'https:')
    )
      fail(503, 'DEPENDENCY_UNAVAILABLE', 'Origen no permitido.');
    return url.origin;
  }
  private async get(url: string, authorization?: string): Promise<Response> {
    try {
      return await fetch(url, {
        headers: authorization ? { Authorization: authorization } : {},
        redirect: 'error',
        signal: AbortSignal.timeout(1800),
      });
    } catch {
      fail(503, 'DEPENDENCY_UNAVAILABLE', 'Dependencia no disponible.');
    }
  }
  private async json(response: Response): Promise<Record<string, unknown>> {
    try {
      const data: unknown = await response.json();
      if (data && typeof data === 'object' && !Array.isArray(data))
        return data as Record<string, unknown>;
    } catch {
      /* malformed response */
    }
    fail(502, 'DEPENDENCY_INVALID_RESPONSE', 'Respuesta de dependencia inválida.');
  }
  async identity(authorization?: string): Promise<Actor> {
    if (!authorization || !/^Bearer\s+\S+$/i.test(authorization))
      fail(401, 'UNAUTHENTICATED', 'Identidad requerida.');
    const response = await this.get(
      this.origin('QUALITY_REPORTS_AUTH_URL') + '/api/v1/auth/access-context',
      authorization,
    );
    if (response.status === 401) fail(401, 'UNAUTHENTICATED', 'Credencial inválida o revocada.');
    if (response.status === 403) fail(403, 'FORBIDDEN', 'Cuenta no autorizada.');
    if (response.status !== 200)
      fail(503, 'DEPENDENCY_UNAVAILABLE', 'No se pudo comprobar la identidad.');
    const data = await this.json(response);
    if (
      typeof data.id !== 'string' ||
      !isUUID(data.id) ||
      data.active !== true ||
      !['STUDENT', 'MODERATOR', 'ADMIN'].includes(data.role as string)
    )
      fail(502, 'DEPENDENCY_INVALID_RESPONSE', 'Identidad inválida.');
    return { id: data.id.toLowerCase(), role: data.role as Actor['role'] };
  }
  async publishedOwner(id: string): Promise<string> {
    const response = await this.get(
      this.origin('QUALITY_REPORTS_MATERIAL_URL') + '/api/v1/materials/' + id,
    );
    if (response.status === 404) fail(404, 'NOT_FOUND', 'Material no disponible.');
    if (response.status !== 200)
      fail(
        response.status >= 500 ? 503 : 502,
        'DEPENDENCY_UNAVAILABLE',
        'No se pudo comprobar el material.',
      );
    const data = await this.json(response);
    if (
      data.id !== id ||
      data.status !== 'PUBLISHED' ||
      typeof data.uploaderId !== 'string' ||
      !isUUID(data.uploaderId)
    )
      fail(502, 'DEPENDENCY_INVALID_RESPONSE', 'Material inválido.');
    return data.uploaderId.toLowerCase();
  }
}
