const FALLBACK_FILENAME = 'material';

/**
 * Elimina caracteres de control (incluye CR/LF) que permitirían inyectar
 * cabeceras adicionales en la respuesta.
 */
function stripControlCharacters(value: string): string {
  let result = '';
  for (const character of value) {
    const codePoint = character.codePointAt(0) ?? 0;
    if (codePoint <= 0x1f || codePoint === 0x7f) continue;
    result += character;
  }
  return result.trim();
}

/** Descarta rutas Unix/Windows y Unicode inválido antes de formar cabeceras. */
function safeBasename(filename?: string): string {
  const base =
    stripControlCharacters(filename ?? '')
      .split(/[\\/]/)
      .pop() ?? '';
  let safe = '';
  for (const character of base) {
    const point = character.codePointAt(0)!;
    if (point >= 0xd800 && point <= 0xdfff) safe += '_';
    else if (point >= 0x80 && point <= 0x9f) continue;
    else if ((point >= 0x202a && point <= 0x202e) || (point >= 0x2066 && point <= 0x2069)) continue;
    else safe += character;
  }
  safe = safe.trim();
  return !safe || /^\.+$/.test(safe) ? FALLBACK_FILENAME : safe;
}

/**
 * Alternativa ASCII segura para clientes que ignoran `filename*` (RFC 5987):
 * quita diacríticos, sustituye lo no imprimible y neutraliza comillas y
 * backslash para no romper el valor entrecomillado ni permitir inyección.
 */
export function asciiFilename(filename?: string): string {
  const base = safeBasename(filename)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
  const safe = base
    .replace(/[^\x20-\x7e]/g, '_')
    .replace(/["\\]/g, '_')
    .replace(/\s+/g, ' ')
    .trim();
  return safe || FALLBACK_FILENAME;
}

/** Nombre original percent-encoded en UTF-8 conforme a RFC 5987 (attr-char). */
export function extendedFilename(filename?: string): string {
  const base = safeBasename(filename);
  return encodeURIComponent(base).replace(
    /['()*]/g,
    (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

/**
 * `Content-Disposition: attachment` que conserva el nombre Unicode original en
 * `filename*` (RFC 5987) y ofrece `filename` como alternativa ASCII segura.
 */
export function buildContentDisposition(
  filename?: string,
  disposition: 'attachment' | 'inline' = 'attachment',
): string {
  return `${disposition}; filename="${asciiFilename(filename)}"; filename*=UTF-8''${extendedFilename(filename)}`;
}
