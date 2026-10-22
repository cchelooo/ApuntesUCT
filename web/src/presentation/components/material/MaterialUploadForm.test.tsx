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
    fireEvent.change(screen.getByTestId('upload-year-input'), {
      target: { value: '2026' },
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
    fireEvent.change(screen.getByTestId('upload-year-input'), {
      target: { value: '2026' },
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
    fireEvent.change(screen.getByTestId('upload-year-input'), {
      target: { value: '2026' },
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
    fireEvent.change(screen.getByTestId('upload-year-input'), {
      target: { value: '2026' },
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
    fireEvent.change(screen.getByTestId('upload-year-input'), {
      target: { value: '2026' },
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

  it('impide subir el material cuando falta el año', async () => {
    const uploadFn = vi.fn();
    render(<MaterialUploadForm uploadFn={uploadFn} />);

    fireEvent.change(screen.getByTestId('upload-title-input'), {
      target: { value: 'Guía de Estudio' },
    });
    fireEvent.change(screen.getByTestId('upload-subject-input'), {
      target: { value: 'MAT-101' },
    });
    await userEvent.upload(
      screen.getByTestId('upload-file-input'),
      new File(['content'], 'guia.pdf', { type: 'application/pdf' })
    );

    fireEvent.click(screen.getByTestId('upload-submit-button'));

    expect(
      await screen.findByText('Por favor, ingresa el año del material.')
    ).toBeInTheDocument();
    expect(uploadFn).not.toHaveBeenCalled();
  });

  it('establece el atributo aria-busy en el formulario y en el botón durante la subida', async () => {
    let resolveUpload: (val: unknown) => void;
    const uploadPromise = new Promise((resolve) => {
      resolveUpload = resolve;
    });
    const uploadFn = vi.fn().mockImplementation(() => uploadPromise);

    render(<MaterialUploadForm uploadFn={uploadFn} />);

    fireEvent.change(screen.getByTestId('upload-title-input'), {
      target: { value: 'Guía de Estudio' },
    });
    fireEvent.change(screen.getByTestId('upload-subject-input'), {
      target: { value: 'MAT-101' },
    });
    fireEvent.change(screen.getByTestId('upload-year-input'), {
      target: { value: '2026' },
    });

    const file = new File(['content'], 'guia.pdf', {
      type: 'application/pdf',
    });
    await userEvent.upload(screen.getByTestId('upload-file-input'), file);

    const form = screen.getByTestId('material-upload-form');
    const submitBtn = screen.getByTestId('upload-submit-button');

    expect(form).toHaveAttribute('aria-busy', 'false');
    expect(submitBtn).toHaveAttribute('aria-busy', 'false');

    fireEvent.click(submitBtn);

    expect(form).toHaveAttribute('aria-busy', 'true');
    expect(submitBtn).toHaveAttribute('aria-busy', 'true');

    resolveUpload!({ id: 'ok-1' });

    await waitFor(() => {
      expect(form).toHaveAttribute('aria-busy', 'false');
      expect(submitBtn).toHaveAttribute('aria-busy', 'false');
    });
  });

  it('limpia las alertas previas al seleccionar un nuevo archivo en el input', async () => {
    const uploadFn = vi.fn().mockRejectedValueOnce({ status: 413 });

    render(<MaterialUploadForm uploadFn={uploadFn} />);

    fireEvent.change(screen.getByTestId('upload-title-input'), {
      target: { value: 'Libro muy pesado' },
    });
    fireEvent.change(screen.getByTestId('upload-subject-input'), {
      target: { value: 'INF-201' },
    });
    fireEvent.change(screen.getByTestId('upload-year-input'), {
      target: { value: '2026' },
    });

    const file = new File(['large content'], 'libro.pdf', {
      type: 'application/pdf',
    });
    const fileInput = screen.getByTestId('upload-file-input');
    await userEvent.upload(fileInput, file);

    fireEvent.click(screen.getByTestId('upload-submit-button'));

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(/15 MB/i);
    });

    // Seleccionar un archivo diferente debe limpiar la alerta
    const newFile = new File(['small'], 'liviano.pdf', {
      type: 'application/pdf',
    });
    fireEvent.change(fileInput, {
      target: { files: [newFile] },
    });

    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });

  it('conserva la confirmación de éxito y no muestra error de subida si el callback onSuccess falla tras la creación', async () => {
    let resolveUpload: (val: unknown) => void;
    const uploadPromise = new Promise((resolve) => {
      resolveUpload = resolve;
    });
    const uploadFn = vi.fn().mockImplementation(() => uploadPromise);
    const onSuccess = vi.fn().mockImplementation(() => {
      throw new Error('Error en onSuccess posterior');
    });
    const onError = vi.fn();

    render(
      <MaterialUploadForm
        uploadFn={uploadFn}
        onSuccess={onSuccess}
        onError={onError}
      />
    );

    fireEvent.change(screen.getByTestId('upload-title-input'), {
      target: { value: 'Guía de Estudio' },
    });
    fireEvent.change(screen.getByTestId('upload-subject-input'), {
      target: { value: 'MAT-101' },
    });
    fireEvent.change(screen.getByTestId('upload-year-input'), {
      target: { value: '2026' },
    });

    const file = new File(['content'], 'guia.pdf', {
      type: 'application/pdf',
    });
    const fileInput = screen.getByTestId('upload-file-input');
    await userEvent.upload(fileInput, file);

    const submitBtn = screen.getByTestId('upload-submit-button');
    fireEvent.click(submitBtn);

    expect(submitBtn).toBeDisabled();
    expect(submitBtn).toHaveTextContent(/subiendo material/i);
    expect(uploadFn).toHaveBeenCalledTimes(1);

    // Resuelve la subida exitosa del material
    resolveUpload!({ id: 'form-mat-1' });

    // La confirmación de subida exitosa debe conservarse
    await waitFor(() => {
      expect(
        screen.getByText('¡Material subido exitosamente!')
      ).toBeInTheDocument();
      expect(screen.getByRole('status')).toBeInTheDocument();
      expect(onSuccess).toHaveBeenCalledTimes(1);
    });

    // No debe reemplazar el éxito por un error de subida ni mostrar mensajes de error simultáneos
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();

    // Se notifica el fallo del callback a onError por separado
    expect(onError).toHaveBeenCalledTimes(1);
  });

  it('conserva la confirmación de éxito y no muestra error de subida si el callback onSuccess retorna una promesa rechazada tras la creación', async () => {
    let resolveUpload: (val: unknown) => void;
    const uploadPromise = new Promise((resolve) => {
      resolveUpload = resolve;
    });
    const uploadFn = vi.fn().mockImplementation(() => uploadPromise);
    const callbackError = new Error('Error asíncrono en onSuccess');
    const onSuccess = vi.fn().mockRejectedValueOnce(callbackError);
    const onError = vi.fn();

    render(
      <MaterialUploadForm
        uploadFn={uploadFn}
        onSuccess={onSuccess}
        onError={onError}
      />
    );

    fireEvent.change(screen.getByTestId('upload-title-input'), {
      target: { value: 'Guía de Estudio Avanzada' },
    });
    fireEvent.change(screen.getByTestId('upload-subject-input'), {
      target: { value: 'MAT-102' },
    });
    fireEvent.change(screen.getByTestId('upload-year-input'), {
      target: { value: '2026' },
    });

    const file = new File(['content'], 'guia.pdf', {
      type: 'application/pdf',
    });
    const fileInput = screen.getByTestId('upload-file-input');
    await userEvent.upload(fileInput, file);

    const submitBtn = screen.getByTestId('upload-submit-button');
    fireEvent.click(submitBtn);

    expect(submitBtn).toBeDisabled();
    expect(uploadFn).toHaveBeenCalledTimes(1);

    // Resuelve la subida exitosa del material
    resolveUpload!({ id: 'form-mat-async' });

    // La confirmación de subida exitosa debe conservarse
    await waitFor(() => {
      expect(
        screen.getByText('¡Material subido exitosamente!')
      ).toBeInTheDocument();
      expect(screen.getByRole('status')).toBeInTheDocument();
      expect(onSuccess).toHaveBeenCalledTimes(1);
      expect(onError).toHaveBeenCalledWith(callbackError);
    });

    // No debe reemplazar el éxito por un error de subida ni mostrar mensajes de error simultáneos
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });
});
