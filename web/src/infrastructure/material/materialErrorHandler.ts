export interface MaterialApiError {
  status?: number;
  message?: string;
  isNetworkError?: boolean;
}

/**
 * Mapea un error de la API de Materiales a un mensaje amigable en español.
 * Aplica para operaciones de subida y descarga de archivos.
 * 
 * Códigos de error manejados:
 * - 400: Solicitud incorrecta (ej. datos faltantes o inválidos)
 * - 401: No autorizado (sesión expirada o token inválido)
 * - 413: Archivo demasiado grande (Payload Too Large)
 * - 415: Tipo de medio no soportado (Unsupported Media Type)
 * - Errores de red o disponibilidad
 */
export function mapMaterialError(error: MaterialApiError | any): string {
  if (error?.isNetworkError || error?.name === 'TypeError' && error?.message === 'Failed to fetch') {
    return 'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.';
  }

  const status = error?.status;

  switch (status) {
    case 400:
      return 'La solicitud es incorrecta. Por favor, revisa los datos e intenta de nuevo.';
    case 401:
      return 'No tienes autorización para realizar esta acción. Por favor, inicia sesión nuevamente.';
    case 413:
      return 'El archivo es demasiado grande. Por favor, selecciona un archivo de menor tamaño.';
    case 415:
      return 'El formato del archivo no es soportado. Por favor, utiliza un formato válido.';
    case 404:
      return 'El material solicitado no fue encontrado.';
    case 500:
    case 502:
    case 503:
    case 504:
      return 'Error temporal en el servidor. Por favor, intenta más tarde.';
    default:
      return 'Ha ocurrido un error inesperado al procesar el material. Por favor, intenta de nuevo.';
  }
}
