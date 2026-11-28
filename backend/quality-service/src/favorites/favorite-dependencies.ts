import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { isUUID } from 'class-validator';
import { FavoriteActor, fail } from './favorite-contract';

/** Sólo REST. El token se delega a Auth para consultar la identidad del propio portador. */
@Injectable()
export class FavoriteDependencies {
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
        signal: AbortSignal.timeout(1500),
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
  async identity(authorization?: string): Promise<FavoriteActor> {
    if (!authorization || !/^Bearer\s+\S+$/i.test(authorization))
      fail(401, 'UNAUTHENTICATED', 'Identidad requerida.');
    const response = await this.get(
      this.origin('QUALITY_FAVORITES_AUTH_URL') + '/api/v1/auth/access-context',
      authorization,
    );
    if (response.status !== 200) await response.body?.cancel();
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
    return { id: data.id.toLowerCase(), role: data.role as FavoriteActor['role'] };
  }
  async available(id: string, signal?: AbortSignal): Promise<boolean> {
    let response: Response;
    try {
      response = await fetch(
        this.origin('QUALITY_FAVORITES_MATERIAL_URL') + '/api/v1/materials/' + id,
        {
          redirect: 'error',
          signal: signal
            ? AbortSignal.any([signal, AbortSignal.timeout(1500)])
            : AbortSignal.timeout(1500),
        },
      );
    } catch {
      fail(503, 'DEPENDENCY_UNAVAILABLE', 'Material no disponible.');
    }
    if (response.status === 404) {
      await response.body?.cancel();
      return false;
    }
    if (response.status !== 200) {
      await response.body?.cancel();
      fail(
        response.status >= 500 ? 503 : 502,
        response.status >= 500 ? 'DEPENDENCY_UNAVAILABLE' : 'DEPENDENCY_INVALID_RESPONSE',
        'No se pudo comprobar la disponibilidad.',
      );
    }
    const data = await this.json(response);
    if (data.id !== id || data.status !== 'PUBLISHED')
      fail(502, 'DEPENDENCY_INVALID_RESPONSE', 'Respuesta de Material inválida.');
    return true;
  }
}
