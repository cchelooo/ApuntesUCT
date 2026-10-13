// @vitest-environment jsdom

import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { MaterialUploadButton } from './MaterialUploadButton';

describe('MaterialUploadButton - Feedback y prevención de dobles envíos (#243)', () => {
  beforeEach(() => {
    window.fetch = vi.fn();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('evita dobles envíos deshabilitando el botón mientras la subida está activa', async () => {
    let resolveUpload: (val: unknown) => void;
    const uploadPromise = new Promise((resolve) => {
      resolveUpload = resolve;
    });
    const uploadFn = vi.fn().mockImplementation(() => uploadPromise);

    render(<MaterialUploadButton uploadFn={uploadFn} />);

    const button = screen.getByTestId('material-upload-button');
    expect(button).not.toBeDisabled();
    expect(button).toHaveTextContent('Subir material');

    const file = new File(['content'], 'resumen.pdf', {
      type: 'application/pdf',
    });
    const input = screen.getByTestId('file-upload-input');
    await userEvent.upload(input, file);

    // Debe pasar a estado deshabilitado con texto de carga
    expect(button).toBeDisabled();
    expect(button).toHaveTextContent(/subiendo material/i);
    expect(uploadFn).toHaveBeenCalledTimes(1);

    // Intentar hacer clic durante la subida no debe disparar otro upload
    fireEvent.click(button);
    expect(uploadFn).toHaveBeenCalledTimes(1);

    // Resolver
    resolveUpload!({ id: '123' });

    await waitFor(() => {
      expect(button).not.toBeDisabled();
      expect(
        screen.getByText('¡Material subido exitosamente!')
      ).toBeInTheDocument();
    });
  });

  it('muestra alerta de error 413 con información de 15 MB y permite reintentar', async () => {
    const uploadFn = vi.fn().mockRejectedValueOnce({ status: 413 });

    render(<MaterialUploadButton uploadFn={uploadFn} />);

    const file = new File(['large content'], 'grande.pdf', {
      type: 'application/pdf',
    });
    await userEvent.upload(screen.getByTestId('file-upload-input'), file);

    await waitFor(() => {
      const alert = screen.getByRole('alert');
      expect(alert).toHaveTextContent(/15 MB/i);
    });

    const button = screen.getByTestId('material-upload-button');
    expect(button).not.toBeDisabled();
    expect(button).toHaveTextContent('Reintentar subida');
  });

  it('muestra alerta de error 415 con detalle de formatos admitidos', async () => {
    const uploadFn = vi.fn().mockRejectedValueOnce({ status: 415 });

    render(<MaterialUploadButton uploadFn={uploadFn} />);

    const file = new File(['bad'], 'archivo.pdf', {
      type: 'application/pdf',
    });
    await userEvent.upload(screen.getByTestId('file-upload-input'), file);

    await waitFor(() => {
      const alert = screen.getByRole('alert');
      expect(alert).toHaveTextContent(/PDF/i);
      expect(alert).toHaveTextContent(/Word/i);
      expect(alert).toHaveTextContent(/PowerPoint/i);
    });
  });

  it('muestra alerta de error 401 indicando la necesidad de autenticación', async () => {
    const uploadFn = vi.fn().mockRejectedValueOnce({ status: 401 });

    render(<MaterialUploadButton uploadFn={uploadFn} />);

    const file = new File(['content'], 'archivo.pdf', {
      type: 'application/pdf',
    });
    await userEvent.upload(screen.getByTestId('file-upload-input'), file);

    await waitFor(() => {
      const alert = screen.getByRole('alert');
      expect(alert).toHaveTextContent(
        'Debes iniciar sesión para subir material. Por favor, autentícate para continuar.'
      );
    });
  });

  it('establece el atributo aria-busy en el botón mientras la subida está en progreso', async () => {
    let resolveUpload: (val: unknown) => void;
    const uploadPromise = new Promise((resolve) => {
      resolveUpload = resolve;
    });
    const uploadFn = vi.fn().mockImplementation(() => uploadPromise);

    render(<MaterialUploadButton uploadFn={uploadFn} />);

    const button = screen.getByTestId('material-upload-button');
    expect(button).toHaveAttribute('aria-busy', 'false');

    const file = new File(['content'], 'resumen.pdf', {
      type: 'application/pdf',
    });
    const input = screen.getByTestId('file-upload-input');
    await userEvent.upload(input, file);

    expect(button).toHaveAttribute('aria-busy', 'true');

    resolveUpload!({ id: 'done' });

    await waitFor(() => {
      expect(button).toHaveAttribute('aria-busy', 'false');
    });
  });
});
