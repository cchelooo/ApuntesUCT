import { describe, expect, it } from 'vitest';
import { mapMaterialError } from './materialErrorHandler';

describe('materialErrorHandler', () => {
  it('Debe mapear un error 400', () => {
    const error = { status: 400 };
    expect(mapMaterialError(error)).toBe(
      'La solicitud es incorrecta. Por favor, revisa los datos e intenta de nuevo.'
    );
  });

  it('Debe mapear un error 401', () => {
    const error = { status: 401 };
    expect(mapMaterialError(error)).toBe(
      'No tienes autorización para realizar esta acción. Por favor, inicia sesión nuevamente.'
    );
  });

  it('Debe mapear un error 413 (Payload Too Large - Subida)', () => {
    const error = { status: 413 };
    expect(mapMaterialError(error)).toBe(
      'El archivo es demasiado grande. Por favor, selecciona un archivo de menor tamaño.'
    );
  });

  it('Debe mapear un error 415 (Unsupported Media Type - Subida)', () => {
    const error = { status: 415 };
    expect(mapMaterialError(error)).toBe(
      'El formato del archivo no es soportado. Por favor, utiliza un formato válido.'
    );
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

  it('Debe devolver un error inesperado para excepciones genéricas', () => {
    const error = new Error('JSON.parse failed');
    expect(mapMaterialError(error)).toBe(
      'Ha ocurrido un error inesperado al procesar el material. Por favor, intenta de nuevo.'
    );
  });
});
