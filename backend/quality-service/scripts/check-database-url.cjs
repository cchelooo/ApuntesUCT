// Se ejecuta antes de migrar mediante npm. No imprime credenciales.
try {
  const value = process.env.DATABASE_URL;
  if (!value) throw new Error('DATABASE_URL es obligatoria.');
  const url = new URL(value);
  if (
    !['postgres:', 'postgresql:'].includes(url.protocol) ||
    url.pathname !== '/quality_db' ||
    !url.hostname
  ) {
    throw new Error('Las migraciones de Quality solo pueden apuntar a quality_db.');
  }
} catch {
  console.error(
    'Configura DATABASE_URL con una URL PostgreSQL válida dirigida a quality_db antes de migrar.',
  );
  process.exitCode = 1;
}
