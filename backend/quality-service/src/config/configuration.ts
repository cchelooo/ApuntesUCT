export interface QualityConfiguration {
  port: number;
  databaseUrl: string;
}

export function validateEnvironment(env: Record<string, unknown>): QualityConfiguration {
  const rawPort = env.PORT ?? '3004';
  if (
    (typeof rawPort !== 'string' && typeof rawPort !== 'number') ||
    !/^\d+$/.test(String(rawPort))
  ) {
    throw new Error('PORT debe ser un entero entre 1 y 65535.');
  }
  const port = Number(rawPort);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT debe ser un entero entre 1 y 65535.');
  }
  if (typeof env.DATABASE_URL !== 'string' || !env.DATABASE_URL.trim()) {
    throw new Error('DATABASE_URL es obligatoria para Quality Service.');
  }
  let url: URL;
  try {
    url = new URL(env.DATABASE_URL);
  } catch {
    throw new Error('DATABASE_URL debe ser una URL PostgreSQL válida.');
  }
  if (!['postgres:', 'postgresql:'].includes(url.protocol) || !url.hostname) {
    throw new Error('DATABASE_URL debe ser una URL PostgreSQL válida.');
  }
  // Evita arrancar accidentalmente con DATABASE_URL de otro workspace.
  if (url.pathname !== '/quality_db') {
    throw new Error('Quality Service debe conectarse a la base quality_db.');
  }
  if (env.QUALITY_MODERATION_ENABLED === 'true') {
    for (const key of [
      'JWT_ACCESS_PUBLIC_KEY',
      'JWT_ISSUER',
      'JWT_AUDIENCE',
      'QUALITY_SERVICE_PRIVATE_KEY',
      'AUTH_INTERNAL_URL',
      'MATERIAL_INTERNAL_URL',
    ]) {
      if (typeof env[key] !== 'string' || !env[key].trim())
        throw new Error(`${key} es obligatoria para moderación.`);
    }
    for (const key of ['AUTH_INTERNAL_URL', 'MATERIAL_INTERNAL_URL']) {
      let target: URL;
      try {
        target = new URL(env[key] as string);
      } catch {
        throw new Error(`${key} debe ser un origen HTTP(S).`);
      }
      if (
        !['http:', 'https:'].includes(target.protocol) ||
        target.username ||
        target.password ||
        target.search ||
        target.hash ||
        target.pathname !== '/' ||
        (env.NODE_ENV === 'production' && target.protocol !== 'https:')
      )
        throw new Error(`${key} requiere un origen válido; HTTPS en producción.`);
    }
  }
  return { port, databaseUrl: env.DATABASE_URL };
}

export default () => ({ quality: validateEnvironment(process.env) });
