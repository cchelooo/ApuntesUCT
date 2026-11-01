export function getApiBaseUrl(): string {
  const baseUrl = import.meta.env.VITE_API_URL?.trim();
  if (!baseUrl) {
    throw new Error('VITE_API_URL no está configurada');
  }

  return baseUrl.replace(/\/+$/, '');
}
