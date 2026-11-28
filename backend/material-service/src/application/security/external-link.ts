import { isURL } from 'class-validator';
import { isIP } from 'node:net';

/**
 * Política de enlaces navegables: HTTP(S), dominio público y sin credenciales.
 * No resuelve DNS ni sigue redirecciones: el servicio nunca consulta estos enlaces.
 * Se excluyen literales IP para no admitir representaciones alternativas de redes privadas.
 */
export function isSafeExternalLink(value: unknown): value is string {
  if (typeof value !== 'string' || /[\s\\]/u.test(value)) return false;
  if (
    Array.from(value).some((character) => {
      const point = character.codePointAt(0)!;
      return point <= 0x1f || point === 0x7f;
    })
  )
    return false;
  if (
    !isURL(value, {
      protocols: ['http', 'https'],
      require_protocol: true,
      require_valid_protocol: true,
      disallow_auth: true,
    })
  )
    return false;

  try {
    const url = new URL(value);
    const host = url.hostname.replace(/\.$/, '');
    if (url.username || url.password || isIP(host) || host.startsWith('[')) return false;
    if (
      !host.includes('.') ||
      /(?:^|\.)(?:localhost|local|internal|lan|home|test|invalid|onion)$/.test(host)
    )
      return false;
    if (host === 'home.arpa' || host.endsWith('.home.arpa')) return false;
    // Las URLs firmadas de almacenamiento contienen credenciales reutilizables.
    for (const key of url.searchParams.keys()) {
      if (/^(?:x-amz-|x-goog-|awsaccesskeyid$|signature$)/i.test(key)) return false;
    }
    return url.protocol === 'https:' || url.protocol === 'http:';
  } catch {
    return false;
  }
}

/** También protege las respuestas de registros anteriores a esta política. */
export function publicExternalLink(value: unknown): string | null {
  return isSafeExternalLink(value) ? value : null;
}
