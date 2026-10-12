// @vitest-environment jsdom

import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { MaterialUploadForm } from './MaterialUploadForm';

describe('MaterialUploadForm - Feedback de subida y contrato de errores (#243)', () => {
  beforeEach(() => {
    window.fetch = vi.fn();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('deshabilita el botón de envío y cambia su estado a carga durante la subida para evitar dobles envíos', async () => {
    let resolveUpload: (val: unknown) => void;
    const uploadPromise = new Promise((resolve) => {
      resolveUpload = resolve;
    });

    const uploadFn = vi.fn().mockImplementation(() => uploadPromise);

    render(<MaterialUploadForm uploadFn={uploadFn} />);

    // Llenar campos requeridos
    fireEvent.change(screen.getByTestId('upload-title-input'), {
      target: { value: 'Guía de Estudio Cálculo' },
    });
    fireEvent.change(screen.getByTestId('upload-subject-input'), {
      target: { value: 'MAT-101' },
    });

    const file = new File(['dummy content'], 'guia.pdf', {
      type: 'application/pdf',
    });
    const fileInput = screen.getByTestId('upload-file-input');
    await userEvent.upload(fileInput, file);

    const submitButton = screen.getByTestId('upload-submit-button');
    expect(submitButton).not.toBeDisabled();
    expect(submitButton).toHaveTextContent('Subir material');

    // Clic en enviar
    fireEvent.click(submitButton);

    // Debe cambiar su estado visual y deshabilitarse
    expect(submitButton).toBeDisabled();
    expect(submitButton).toHaveTextContent(/subiendo material/i);
    expect(uploadFn).toHaveBeenCalledTimes(1);

    // Intento de doble envío mientras está activo: no debe volver a llamar a uploadFn
    fireEvent.click(submitButton);
    expect(uploadFn).toHaveBeenCalledTimes(1);

    // Finalizar petición
    resolveUpload!({ id: 'mat-123' });

    await waitFor(() => {
      expect(submitButton).not.toBeDisabled();
      expect(submitButton).toHaveTextContent('Subir material');
      expect(
        screen.getByText('¡Material subido exitosamente!')
      ).toBeInTheDocument();
    });
  });

  it('muestra alerta clara con el límite de 15 MB ante un error 413 (Payload Too Large)', async () => {
    const uploadFn = vi.fn().mockRejectedValueOnce({ status: 413 });

    render(<MaterialUploadForm uploadFn={uploadFn} />);

    fireEvent.change(screen.getByTestId('upload-title-input'), {
      target: { value: 'Libro muy pesado' },
    });
    fireEvent.change(screen.getByTestId('upload-subject-input'), {
      target: { value: 'INF-201' },
    });

    const file = new File(['large content'], 'libro.pdf', {
      type: 'application/pdf',
    });
    await userEvent.upload(screen.getByTestId('upload-file-input'), file);

    fireEvent.click(screen.getByTestId('upload-submit-button'));

    await waitFor(() => {
      const alert = screen.getByRole('alert');
      expect(alert).toBeInTheDocument();
      expect(alert).toHaveTextContent(/15 MB/i);
      expect(alert).toHaveTextContent(
        'El archivo supera el tamaño máximo permitido de 15 MB. Por favor, selecciona un archivo de menor tamaño.'
      );
    });

    // El botón vuelve a habilitarse para permitir reintentar con otro archivo
    expect(screen.getByTestId('upload-submit-button')).not.toBeDisabled();
  });

  it('muestra alerta detallando los formatos admitidos ante un error 415 (Unsupported Media Type)', async () => {
    const uploadFn = vi.fn().mockRejectedValueOnce({ status: 415 });

    render(<MaterialUploadForm uploadFn={uploadFn} />);

    fireEvent.change(screen.getByTestId('upload-title-input'), {
      target: { value: 'Archivo no soportado' },
    });
    fireEvent.change(screen.getByTestId('upload-subject-input'), {
      target: { value: 'INF-201' },
    });

    const file = new File(['unsupported'], 'corrupted.pdf', {
      type: 'application/pdf',
    });
    await userEvent.upload(screen.getByTestId('upload-file-input'), file);

    fireEvent.click(screen.getByTestId('upload-submit-button'));

    await waitFor(() => {
      const alert = screen.getByRole('alert');
      expect(alert).toBeInTheDocument();
      expect(alert).toHaveTextContent(/PDF/i);
      expect(alert).toHaveTextContent(/Word \(\.doc, \.docx\)/i);
      expect(alert).toHaveTextContent(/PowerPoint \(\.ppt, \.pptx\)/i);
      expect(alert).toHaveTextContent(
        'El formato del archivo no es soportado. Formatos aceptados: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).'
      );
    });
  });

  it('muestra alerta informando la necesidad de autenticación ante un error 401 (Unauthorized)', async () => {
    const uploadFn = vi.fn().mockRejectedValueOnce({ status: 401 });

    render(<MaterialUploadForm uploadFn={uploadFn} />);

    fireEvent.change(screen.getByTestId('upload-title-input'), {
      target: { value: 'Apunte anónimo' },
    });
    fireEvent.change(screen.getByTestId('upload-subject-input'), {
      target: { value: 'INF-201' },
    });

    const file = new File(['content'], 'apunte.pdf', {
      type: 'application/pdf',
    });
    await userEvent.upload(screen.getByTestId('upload-file-input'), file);

    fireEvent.click(screen.getByTestId('upload-submit-button'));

    await waitFor(() => {
      const alert = screen.getByRole('alert');
      expect(alert).toBeInTheDocument();
      expect(alert).toHaveTextContent(
        'Debes iniciar sesión para subir material. Por favor, autentícate para continuar.'
      );
    });
  });

  it('muestra alerta de fallo de red ante problemas de conectividad', async () => {
    const uploadFn = vi.fn().mockRejectedValueOnce({ isNetworkError: true });

    render(<MaterialUploadForm uploadFn={uploadFn} />);

    fireEvent.change(screen.getByTestId('upload-title-input'), {
      target: { value: 'Apunte' },
    });
    fireEvent.change(screen.getByTestId('upload-subject-input'), {
      target: { value: 'INF-201' },
    });

    const file = new File(['content'], 'apunte.pdf', {
      type: 'application/pdf',
    });
    await userEvent.upload(screen.getByTestId('upload-file-input'), file);

    fireEvent.click(screen.getByTestId('upload-submit-button'));

    await waitFor(() => {
      const alert = screen.getByRole('alert');
      expect(alert).toBeInTheDocument();
      expect(alert).toHaveTextContent(
        'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.'
      );
    });
  });

  it('valida campos requeridos y exige archivo si el tipo es documento', async () => {
    render(<MaterialUploadForm />);

    fireEvent.click(screen.getByTestId('upload-submit-button'));

    await waitFor(() => {
      expect(
        screen.getByText('Por favor, ingresa el título del material.')
      ).toBeInTheDocument();
    });
  });
});
