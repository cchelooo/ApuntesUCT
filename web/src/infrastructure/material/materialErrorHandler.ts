export interface MaterialApiError {
  status?: number;
  message?: string;
  isNetworkError?: boolean;
  name?: string;
}

/**
 * Mapea un error de la API de Materiales a un mensaje amigable en español.
 * Aplica para operaciones de subida y descarga de archivos.
 *
 * ALCANCE DE SUBIDA (PENDIENTE):
 * Aunque este mapeo está completamente preparado para manejar errores de subida
 * (como 413 Payload Too Large y 415 Unsupported Media Type), actualmente solo
 * se está utilizando en el flujo de descarga (MaterialDownloadButton).
 * La integración con la operación de subida queda pendiente para una próxima tarea,
 * cuando se implemente el componente respectivo de UI.
 *
 * Códigos de error manejados:
 * - 400: Solicitud incorrecta (ej. datos faltantes o inválidos)
 * - 401: No autorizado (sesión expirada o token inválido)
 * - 413: Archivo demasiado grande (Payload Too Large)
 * - 415: Tipo de medio no soportado (Unsupported Media Type)
 * - Errores de red o disponibilidad
 */
export function mapMaterialError(error: unknown): string {
  // Verificamos si es un error tipado conocido (nuestra interfaz)
  const isMaterialApiError = (err: unknown): err is MaterialApiError => {
    return typeof err === 'object' && err !== null;
  };

  if (isMaterialApiError(error)) {
    // Distinguir explícitamente fallos de red reales (marcados previamente en el catch del fetch)
    if (error.isNetworkError) {
      return 'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.';
    }

    const apiError = error as MaterialApiError;
    const status = apiError.status;

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
    }
  }

  // Cualquier otra excepción genérica o inesperada al procesar (blob fail, json fail, etc)
  return 'Ha ocurrido un error inesperado al procesar el material. Por favor, intenta de nuevo.';
}
