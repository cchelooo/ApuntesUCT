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

  it('resetea el valor del selector/input de archivo tras un error permitiendo volver a seleccionar el mismo archivo', async () => {
    const uploadFn = vi
      .fn()
      .mockRejectedValueOnce({ status: 413 })
      .mockResolvedValueOnce({ id: 'ok-2' });

    render(<MaterialUploadButton uploadFn={uploadFn} />);

    const file = new File(['content'], 'mismo-archivo.pdf', {
      type: 'application/pdf',
    });
    const input = screen.getByTestId('file-upload-input') as HTMLInputElement;

    // Primer intento: Falla con error 413
    await userEvent.upload(input, file);

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(/15 MB/i);
    });

    // El input debe haberse reseteado a vacío tras el fallo
    expect(input.value).toBe('');

    // Permite reintentar seleccionando exactamente el mismo archivo
    await userEvent.upload(input, file);

    await waitFor(() => {
      expect(
        screen.getByText('¡Material subido exitosamente!')
      ).toBeInTheDocument();
    });
    expect(uploadFn).toHaveBeenCalledTimes(2);
  });

  it('no muestra alertas de éxito y error simultáneamente si el callback onSuccess lanza un error tras la subida', async () => {
    const uploadFn = vi.fn().mockResolvedValueOnce({ id: 'mat-created' });
    const onSuccess = vi.fn().mockImplementation(() => {
      throw new Error('Error en callback posterior');
    });
    const onError = vi.fn();

    render(
      <MaterialUploadButton
        uploadFn={uploadFn}
        onSuccess={onSuccess}
        onError={onError}
      />
    );

    const file = new File(['content'], 'apunte.pdf', {
      type: 'application/pdf',
    });
    const input = screen.getByTestId('file-upload-input');
    await userEvent.upload(input, file);

    await waitFor(() => {
      expect(screen.getByRole('alert')).toBeInTheDocument();
    });

    // Se asegura de que no coexistan mensajes de éxito y error al mismo tiempo
    expect(
      screen.queryByText('¡Material subido exitosamente!')
    ).not.toBeInTheDocument();
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
    expect(onError).toHaveBeenCalledTimes(1);
  });

  it('limpia la alerta de error previa al completar una subida exitosa', async () => {
    const uploadFn = vi
      .fn()
      .mockRejectedValueOnce({ status: 415 })
      .mockResolvedValueOnce({ id: 'ok-reintento' });

    render(<MaterialUploadButton uploadFn={uploadFn} />);

    const file = new File(['bad'], 'archivo.pdf', {
      type: 'application/pdf',
    });
    const input = screen.getByTestId('file-upload-input');

    // Intento 1: Falla con error 415
    await userEvent.upload(input, file);
    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(/PDF/i);
    });

    // Intento 2: Éxito en la subida
    await userEvent.upload(input, file);
    await waitFor(() => {
      expect(
        screen.getByText('¡Material subido exitosamente!')
      ).toBeInTheDocument();
      expect(screen.getByRole('status')).toBeInTheDocument();
    });

    // La alerta de error no debe coexistir con la de éxito
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });
});
