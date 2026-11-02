export default () => ({
  port: parseInt(process.env.PORT ?? '3003', 10),
  catalog: {
    // Incluye /api/v1; el adaptador añade /catalog y sus rutas.
    baseUrl: process.env.CATALOG_SERVICE_URL ?? 'http://localhost:3002/api/v1',
    timeoutMs: Number(process.env.CATALOG_TIMEOUT_MS ?? '5000'),
  },
});
