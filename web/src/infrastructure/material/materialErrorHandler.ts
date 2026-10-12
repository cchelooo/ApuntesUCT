export interface MaterialApiError {
  status?: number;
  message?: string;
  isNetworkError?: boolean;
  name?: string;
}

export type MaterialErrorContext = 'upload' | 'download' | 'general';

/**
 * Mapea un error de la API de Materiales a un mensaje amigable en español.
 * Aplica para operaciones de subida y descarga de archivos.
 *
 * Contrato de errores para subida de archivos (Issue #243):
 * - 400: Solicitud incorrecta (metadatos inválidos o faltantes)
 * - 401: Requiere autenticación (informa necesidad de iniciar sesión para subir material)
 * - 413: Archivo demasiado grande (informa explícitamente el límite máximo de 15 MB)
 * - 415: Tipo de medio no soportado (detalla formatos admitidos: PDF, Word y PowerPoint)
 * - 404: Material no encontrado (operaciones de consulta y descarga)
 * - 500, 502, 503, 504: Errores temporales de disponibilidad del servidor
 * - Errores de red o conectividad
 */
export function mapMaterialError(
  error: unknown,
  context: MaterialErrorContext = 'upload'
): string {
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
        return context === 'upload'
          ? 'Debes iniciar sesión para subir material. Por favor, autentícate para continuar.'
          : 'No tienes autorización para realizar esta acción. Por favor, inicia sesión nuevamente.';
      case 413:
        return 'El archivo supera el tamaño máximo permitido de 15 MB. Por favor, selecciona un archivo de menor tamaño.';
      case 415:
        return 'El formato del archivo no es soportado. Formatos aceptados: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).';
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

/**
 * Función auxiliar específica para mapear errores en flujos de subida de archivos.
 */
export function mapMaterialUploadError(error: unknown): string {
  return mapMaterialError(error, 'upload');
}
