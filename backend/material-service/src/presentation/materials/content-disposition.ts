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

/**
 * Alternativa ASCII segura para clientes que ignoran `filename*` (RFC 5987):
 * quita diacríticos, sustituye lo no imprimible y neutraliza comillas y
 * backslash para no romper el valor entrecomillado ni permitir inyección.
 */
export function asciiFilename(filename?: string): string {
  const base = stripControlCharacters(filename ?? '')
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
  const base = stripControlCharacters(filename ?? '') || FALLBACK_FILENAME;
  return encodeURIComponent(base).replace(
    /['()*]/g,
    (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

/**
 * `Content-Disposition: attachment` que conserva el nombre Unicode original en
 * `filename*` (RFC 5987) y ofrece `filename` como alternativa ASCII segura.
 */
export function buildContentDisposition(filename?: string): string {
  return `attachment; filename="${asciiFilename(filename)}"; filename*=UTF-8''${extendedFilename(filename)}`;
}
