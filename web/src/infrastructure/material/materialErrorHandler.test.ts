import { describe, expect, it } from 'vitest';
import {
  mapMaterialError,
  mapMaterialUploadError,
} from './materialErrorHandler';

describe('materialErrorHandler', () => {
  it('Debe mapear un error 400', () => {
    const error = { status: 400 };
    expect(mapMaterialError(error)).toBe(
      'La solicitud es incorrecta. Por favor, revisa los datos e intenta de nuevo.'
    );
  });

  it('Debe mapear un error 401 informando la necesidad de autenticación en subida', () => {
    const error = { status: 401 };
    expect(mapMaterialError(error, 'upload')).toBe(
      'Debes iniciar sesión para subir material. Por favor, autentícate para continuar.'
    );
    // Por defecto también debe orientarse al flujo de subida
    expect(mapMaterialError(error)).toBe(
      'Debes iniciar sesión para subir material. Por favor, autentícate para continuar.'
    );
    expect(mapMaterialUploadError(error)).toBe(
      'Debes iniciar sesión para subir material. Por favor, autentícate para continuar.'
    );
  });

  it('Debe mapear un error 401 en contexto de descarga', () => {
    const error = { status: 401 };
    expect(mapMaterialError(error, 'download')).toBe(
      'No tienes autorización para realizar esta acción. Por favor, inicia sesión nuevamente.'
    );
  });

  it('Debe mapear un error 413 informando claramente sobre el límite de 15 MB', () => {
    const error = { status: 413 };
    const mensaje = mapMaterialError(error);
    expect(mensaje).toBe(
      'El archivo supera el tamaño máximo permitido de 15 MB. Por favor, selecciona un archivo de menor tamaño.'
    );
    expect(mensaje).toContain('15 MB');
    expect(mapMaterialUploadError(error)).toContain('15 MB');
  });

  it('Debe mapear un error 415 detallando los formatos de archivo aceptados', () => {
    const error = { status: 415 };
    const mensaje = mapMaterialError(error);
    expect(mensaje).toBe(
      'El formato del archivo no es soportado. Formatos aceptados: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).'
    );
    expect(mensaje).toContain('PDF');
    expect(mensaje).toContain('Word (.doc, .docx)');
    expect(mensaje).toContain('PowerPoint (.ppt, .pptx)');
    expect(mapMaterialUploadError(error)).toContain('PDF');
  });

  it('Debe mapear errores de disponibilidad (500)', () => {
    const error = { status: 500 };
    expect(mapMaterialError(error)).toBe(
      'Error temporal en el servidor. Por favor, intenta más tarde.'
    );
  });

  it('Debe devolver un error inesperado para un TypeError sin marcar (ej. Failed to fetch)', () => {
    const error = new TypeError('Failed to fetch');
    expect(mapMaterialError(error)).toBe(
      'Ha ocurrido un error inesperado al procesar el material. Por favor, intenta de nuevo.'
    );
  });

  it('Debe distinguir un error de red mediante isNetworkError', () => {
    const error = { isNetworkError: true };
    expect(mapMaterialError(error)).toBe(
      'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.'
    );
  });

  it('Debe soportar statusCode alternativo (común en respuestas REST)', () => {
    const error = { statusCode: 413 };
    expect(mapMaterialUploadError(error)).toContain('15 MB');
  });

  it('Debe soportar objetos de respuesta Axios/HTTP anidados con response.status', () => {
    const error = { response: { status: 415 } };
    expect(mapMaterialUploadError(error)).toContain('PDF');
  });

  it('Debe devolver un error inesperado para excepciones genéricas', () => {
    const error = new Error('JSON.parse failed');
    expect(mapMaterialError(error)).toBe(
      'Ha ocurrido un error inesperado al procesar el material. Por favor, intenta de nuevo.'
    );
  });
});
