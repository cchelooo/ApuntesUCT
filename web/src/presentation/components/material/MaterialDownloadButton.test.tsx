// @vitest-environment jsdom

import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { MaterialDownloadButton } from './MaterialDownloadButton';

describe('MaterialDownloadButton', () => {
  beforeEach(() => {
    window.fetch = vi.fn();
    // Mock createObjectURL y revokeObjectURL
    window.URL.createObjectURL = vi.fn(() => 'mocked-url');
    window.URL.revokeObjectURL = vi.fn();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('Debe mostrar la alerta y permitir reintento cuando falla la descarga por error 404', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: false,
      status: 404,
    } as Response);

    render(<MaterialDownloadButton url="http://mock-url" />);

    const button = screen.getByRole('button', { name: /Descargar material/i });
    fireEvent.click(button);

    // Debe mostrar la alerta con el mensaje correspondiente al 404
    await waitFor(() => {
      expect(
        screen.getByText('El material solicitado no fue encontrado.')
      ).toBeTruthy();
    });

    // El botón debe cambiar a "Reintentar descarga"
    expect(
      screen.getByRole('button', { name: /Reintentar descarga/i })
    ).toBeTruthy();
  });

  it('Debe mostrar alerta de conexión cuando falla la red y permitir reintento exitoso', async () => {
    // Primer intento: Falla la red
    vi.mocked(window.fetch).mockRejectedValueOnce(
      new TypeError('Failed to fetch')
    );
    // Segundo intento: Éxito
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: true,
      blob: () =>
        Promise.resolve(
          new Blob(['dummy content'], { type: 'application/pdf' })
        ),
      headers: new Headers({
        'Content-Disposition': 'attachment; filename="archivo-prueba.pdf"',
      }),
    } as unknown as Response);

    render(<MaterialDownloadButton url="http://mock-url" />);

    const button = screen.getByRole('button', { name: /Descargar material/i });
    fireEvent.click(button);

    // Debe mostrar la alerta de error de conexión
    await waitFor(() => {
      expect(
        screen.getByText(
          'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.'
        )
      ).toBeTruthy();
    });

    // El botón debe permitir reintentar
    const retryButton = screen.getByRole('button', {
      name: /Reintentar descarga/i,
    });
    expect(retryButton).toBeTruthy();

    // Simular clic nuevamente
    fireEvent.click(retryButton);

    // La alerta debe desaparecer (ya no está en el documento)
    await waitFor(() => {
      expect(
        screen.queryByText(
          'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.'
        )
      ).toBeNull();
    });

    // Se debe haber llamado a fetch 2 veces en total
    expect(window.fetch).toHaveBeenCalledTimes(2);

    // La descarga se completa con éxito (se crea la URL para el blob)
    expect(window.URL.createObjectURL).toHaveBeenCalled();
  });

  it('No debe mostrar error de conexión si ocurre un error genérico (ej. Blob fail)', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: true,
      blob: () => Promise.reject(new Error('Unknown generic error on blob()')),
    } as Response);

    render(<MaterialDownloadButton url="http://mock-url" />);

    const button = screen.getByRole('button', { name: /Descargar material/i });
    fireEvent.click(button);

    // Debe mostrar la alerta genérica de error inesperado, no la de red
    await waitFor(() => {
      expect(
        screen.getByText(
          'Ha ocurrido un error inesperado al procesar el material. Por favor, intenta de nuevo.'
        )
      ).toBeTruthy();
    });
  });
});
