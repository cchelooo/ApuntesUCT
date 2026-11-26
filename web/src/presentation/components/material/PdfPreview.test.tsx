import { render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PdfPreview } from './PdfPreview';

describe('PdfPreview', () => {
  beforeEach(() => {
    window.fetch = vi.fn();
    window.URL.createObjectURL = vi.fn(() => 'blob:pdf-preview');
    window.URL.revokeObjectURL = vi.fn();
  });

  it('muestra la previsualización cuando el PDF carga correctamente', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: true,
      blob: () =>
        Promise.resolve(new Blob(['%PDF-1.7'], { type: 'application/pdf' })),
    } as unknown as Response);

    render(
      <PdfPreview
        previewUrl="/api/v1/materials/material-1/preview"
        downloadUrl="/api/v1/materials/material-1/download"
      />
    );

    expect(screen.getByRole('status')).toHaveTextContent(
      'Cargando previsualización'
    );
    expect(
      await screen.findByTitle('Previsualización del material')
    ).toHaveAttribute('src', 'blob:pdf-preview');
  });

  it('ofrece descarga alternativa ante 403 sin acceso', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: false,
      status: 403,
    } as Response);

    render(
      <PdfPreview
        previewUrl="/api/v1/materials/material-1/preview"
        downloadUrl="/api/v1/materials/material-1/download"
      />
    );

    expect(
      await screen.findByText(
        'La previsualización no está disponible por permisos o acceso al archivo.'
      )
    ).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Descargar PDF' })).toHaveAttribute(
      'href',
      '/api/v1/materials/material-1/download'
    );
  });

  it('ofrece descarga alternativa ante un fallo de carga', async () => {
    vi.mocked(window.fetch).mockRejectedValueOnce(
      new TypeError('Failed to fetch')
    );

    render(
      <PdfPreview
        previewUrl="/api/v1/materials/material-1/preview"
        downloadUrl="/api/v1/materials/material-1/download"
      />
    );

    expect(
      await screen.findByText(
        'No fue posible cargar la previsualización del PDF.'
      )
    ).toBeInTheDocument();
    expect(
      screen.getByRole('link', { name: 'Descargar PDF' })
    ).toBeInTheDocument();
  });

  it('muestra la alternativa aun cuando no exista URL de previsualización', () => {
    render(
      <PdfPreview
        previewUrl={null}
        downloadUrl="/api/v1/materials/material-1/download"
      />
    );

    expect(screen.getByRole('link', { name: 'Descargar PDF' })).toHaveAttribute(
      'href',
      '/api/v1/materials/material-1/download'
    );
  });

  it('revoca el objeto creado al desmontar', async () => {
    vi.mocked(window.fetch).mockResolvedValueOnce({
      ok: true,
      blob: () =>
        Promise.resolve(new Blob(['%PDF-1.7'], { type: 'application/pdf' })),
    } as unknown as Response);

    const { unmount } = render(
      <PdfPreview
        previewUrl="/api/v1/materials/material-1/preview"
        downloadUrl="/api/v1/materials/material-1/download"
      />
    );
    await screen.findByTitle('Previsualización del material');

    unmount();
    await waitFor(() => {
      expect(window.URL.revokeObjectURL).toHaveBeenCalledWith(
        'blob:pdf-preview'
      );
    });
  });
});
