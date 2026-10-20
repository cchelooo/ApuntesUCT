// @vitest-environment jsdom

import {
  render,
  screen,
  fireEvent,
  waitFor,
  within,
} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { MaterialUploadForm } from './MaterialUploadForm';

describe('MaterialUploadForm - Cobertura de pruebas y regresión (#244)', () => {
  beforeEach(() => {
    window.fetch = vi.fn();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('Criterios de aceptación - Selección y reflejo de archivo', () => {
    it('permite seleccionar un archivo y lo refleja visualmente con su nombre, tamaño y botón para removerlo', async () => {
      render(<MaterialUploadForm />);

      const file = new File(
        ['contenido de prueba para simular archivo'],
        'guia-calculo.pdf',
        {
          type: 'application/pdf',
        }
      );
      const fileInput = screen.getByTestId('upload-file-input');

      await userEvent.upload(fileInput, file);

      // El archivo debe reflejarse en la interfaz en un contenedor con rol status
      const statusContainer = screen.getByRole('status');
      expect(statusContainer).toBeInTheDocument();
      expect(statusContainer).toHaveTextContent(/guia-calculo\.pdf/i);
      expect(within(statusContainer).getByText(/MB/i)).toBeInTheDocument();
      expect(
        screen.getByRole('button', { name: /quitar archivo/i })
      ).toBeInTheDocument();
    });
  });

  describe('Criterios de aceptación - Envío correcto de metadatos y archivo en FormData', () => {
    it('entrega una instancia de FormData a uploadFn con todos los metadatos y el archivo adjunto', async () => {
      const uploadFn = vi.fn().mockResolvedValue({ id: 'mat-244-ok' });
      const onSuccess = vi.fn();

      render(<MaterialUploadForm uploadFn={uploadFn} onSuccess={onSuccess} />);

      // Completar metadatos requeridos y opcionales
      fireEvent.change(screen.getByTestId('upload-title-input'), {
        target: { value: 'Guía de Ecuaciones Diferenciales' },
      });
      fireEvent.change(screen.getByTestId('upload-description-input'), {
        target: { value: 'Ejercicios prácticos con soluciones paso a paso' },
      });
      fireEvent.change(screen.getByTestId('upload-year-input'), {
        target: { value: '2026' },
      });
      fireEvent.change(screen.getByTestId('upload-type-select'), {
        target: { value: 'DOCUMENT' },
      });
      fireEvent.change(screen.getByTestId('upload-subject-input'), {
        target: { value: 'MAT-204' },
      });

      const file = new File(['contenido binario simulado'], 'ecuaciones.pdf', {
        type: 'application/pdf',
      });
      const fileInput = screen.getByTestId('upload-file-input');
      await userEvent.upload(fileInput, file);

      // Enviar formulario
      const submitButton = screen.getByTestId('upload-submit-button');
      fireEvent.click(submitButton);

      await waitFor(() => {
        expect(uploadFn).toHaveBeenCalledTimes(1);
      });

      // Validar contrato estricto de FormData
      const formData = uploadFn.mock.calls[0][0] as FormData;
      expect(formData).toBeInstanceOf(FormData);
      expect(formData.get('title')).toBe('Guía de Ecuaciones Diferenciales');
      expect(formData.get('description')).toBe(
        'Ejercicios prácticos con soluciones paso a paso'
      );
      expect(formData.get('year')).toBe('2026');
      expect(formData.get('type')).toBe('DOCUMENT');
      expect(formData.get('subjectId')).toBe('MAT-204');

      // Validar que el archivo entregado en el FormData es el seleccionado
      const sentFile = formData.get('file') as File;
      expect(sentFile).toBeInstanceOf(File);
      expect(sentFile.name).toBe('ecuaciones.pdf');
      expect(sentFile.type).toBe('application/pdf');

      expect(onSuccess).toHaveBeenCalledWith({ id: 'mat-244-ok' });
    });

    it('entrega FormData con enlace externo y omite el campo file cuando el tipo es LINK', async () => {
      const uploadFn = vi.fn().mockResolvedValue({ id: 'link-mat-1' });

      render(<MaterialUploadForm uploadFn={uploadFn} />);

      fireEvent.change(screen.getByTestId('upload-title-input'), {
        target: { value: 'Videotutorial de Integrales' },
      });
      fireEvent.change(screen.getByTestId('upload-subject-input'), {
        target: { value: 'MAT-101' },
      });
      fireEvent.change(screen.getByTestId('upload-type-select'), {
        target: { value: 'LINK' },
      });

      const linkInput = screen.getByTestId('upload-link-input');
      expect(linkInput).toBeInTheDocument();
      fireEvent.change(linkInput, {
        target: { value: 'https://youtube.com/watch?v=integrales' },
      });

      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(uploadFn).toHaveBeenCalledTimes(1);
      });

      const formData = uploadFn.mock.calls[0][0] as FormData;
      expect(formData.get('type')).toBe('LINK');
      expect(formData.get('externalLink')).toBe(
        'https://youtube.com/watch?v=integrales'
      );
      expect(formData.has('file')).toBe(false);
      expect(formData.get('file')).toBeNull();
    });
  });

  describe('Criterios de aceptación - Simulación de errores HTTP 413 y 415', () => {
    it('simula error HTTP 413 (Payload Too Large): propaga a onError y muestra alerta con límite de 15 MB', async () => {
      const error413 = { status: 413, message: 'Payload Too Large' };
      const uploadFn = vi.fn().mockRejectedValue(error413);
      const onError = vi.fn();

      render(<MaterialUploadForm uploadFn={uploadFn} onError={onError} />);

      fireEvent.change(screen.getByTestId('upload-title-input'), {
        target: { value: 'Libro pesado' },
      });
      fireEvent.change(screen.getByTestId('upload-subject-input'), {
        target: { value: 'INF-201' },
      });

      const file = new File(['archivo muy pesado'], 'libro-100mb.pdf', {
        type: 'application/pdf',
      });
      await userEvent.upload(screen.getByTestId('upload-file-input'), file);

      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(uploadFn).toHaveBeenCalledTimes(1);
        expect(onError).toHaveBeenCalledWith(error413);
      });

      const alert = await screen.findByRole('alert');
      expect(alert).toBeInTheDocument();
      expect(alert).toHaveTextContent(/15 MB/i);
      expect(alert).toHaveTextContent(
        'El archivo supera el tamaño máximo permitido de 15 MB. Por favor, selecciona un archivo de menor tamaño.'
      );

      // El botón debe rehabilitarse para permitir reintentar con otro archivo
      expect(screen.getByTestId('upload-submit-button')).not.toBeDisabled();
    });

    it('simula error HTTP 415 (Unsupported Media Type): propaga a onError y detalla formatos admitidos', async () => {
      const error415 = { status: 415, message: 'Unsupported Media Type' };
      const uploadFn = vi.fn().mockRejectedValue(error415);
      const onError = vi.fn();

      render(<MaterialUploadForm uploadFn={uploadFn} onError={onError} />);

      fireEvent.change(screen.getByTestId('upload-title-input'), {
        target: { value: 'Formato no soportado' },
      });
      fireEvent.change(screen.getByTestId('upload-subject-input'), {
        target: { value: 'INF-201' },
      });

      const file = new File(['contenido de prueba'], 'documento.pdf', {
        type: 'application/pdf',
      });
      await userEvent.upload(screen.getByTestId('upload-file-input'), file);

      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(uploadFn).toHaveBeenCalledTimes(1);
        expect(onError).toHaveBeenCalledWith(error415);
      });

      const alert = await screen.findByRole('alert');
      expect(alert).toBeInTheDocument();
      expect(alert).toHaveTextContent(/PDF/i);
      expect(alert).toHaveTextContent(/Word \(\.doc, \.docx\)/i);
      expect(alert).toHaveTextContent(/PowerPoint \(\.ppt, \.pptx\)/i);
      expect(alert).toHaveTextContent(
        'El formato del archivo no es soportado. Formatos aceptados: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).'
      );

      expect(screen.getByTestId('upload-submit-button')).not.toBeDisabled();
    });

    it('simula errores HTTP 413 y 415 utilizando el cliente uploadMaterial por defecto con fetch simulado', async () => {
      // Simulación de respuesta 413 del backend
      const fetchMock = vi
        .fn()
        .mockResolvedValueOnce(
          new Response(
            JSON.stringify({ message: 'El archivo supera el tamaño máximo' }),
            { status: 413, headers: { 'Content-Type': 'application/json' } }
          )
        );
      window.fetch = fetchMock;
      const onError = vi.fn();

      render(<MaterialUploadForm onError={onError} />);

      fireEvent.change(screen.getByTestId('upload-title-input'), {
        target: { value: 'Material por defecto fetch' },
      });
      fireEvent.change(screen.getByTestId('upload-subject-input'), {
        target: { value: 'INF-100' },
      });

      const file = new File(['bytes'], 'grande.pdf', {
        type: 'application/pdf',
      });
      await userEvent.upload(screen.getByTestId('upload-file-input'), file);

      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(fetchMock).toHaveBeenCalledTimes(1);
        expect(onError).toHaveBeenCalledTimes(1);
      });

      const alert413 = await screen.findByRole('alert');
      expect(alert413).toHaveTextContent(/15 MB/i);

      // Simulación de respuesta 415 del backend
      fetchMock.mockResolvedValueOnce(
        new Response(JSON.stringify({ message: 'Tipo no soportado' }), {
          status: 415,
          headers: { 'Content-Type': 'application/json' },
        })
      );

      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(fetchMock).toHaveBeenCalledTimes(2);
      });

      const alert415 = await screen.findByRole('alert');
      expect(alert415).toHaveTextContent(
        'El formato del archivo no es soportado. Formatos aceptados: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).'
      );
    });
  });

  describe('Criterios de aceptación - Estado loading y prevención de envíos duplicados', () => {
    it('muestra estado loading con promesa pendiente, desocupa el botón y bloquea llamadas duplicadas', async () => {
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

      const file = new File(['contenido'], 'guia.pdf', {
        type: 'application/pdf',
      });
      await userEvent.upload(screen.getByTestId('upload-file-input'), file);

      const submitButton = screen.getByTestId('upload-submit-button');
      const form = screen.getByTestId('material-upload-form');

      expect(submitButton).not.toBeDisabled();
      expect(submitButton).toHaveTextContent('Subir material');
      expect(submitButton).toHaveAttribute('aria-busy', 'false');
      expect(form).toHaveAttribute('aria-busy', 'false');

      // Primer clic de envío
      fireEvent.click(submitButton);

      // Verificación de estado de carga inmediato
      expect(uploadFn).toHaveBeenCalledTimes(1);
      expect(submitButton).toBeDisabled();
      expect(submitButton).toHaveTextContent(/subiendo material/i);
      expect(submitButton).toHaveAttribute('aria-busy', 'true');
      expect(form).toHaveAttribute('aria-busy', 'true');
      expect(screen.getByTestId('upload-title-input')).toBeDisabled();

      // Clics adicionales e intentos de re-envío mientras está la promesa pendiente
      fireEvent.click(submitButton);
      fireEvent.click(submitButton);
      fireEvent.submit(form);

      // Comprobar estrictamente que NO hubo envíos duplicados
      expect(uploadFn).toHaveBeenCalledTimes(1);

      // Liberar promesa pendiente
      resolveUpload!({ id: 'subida-completada' });

      await waitFor(() => {
        expect(submitButton).not.toBeDisabled();
        expect(submitButton).toHaveTextContent('Subir material');
        expect(submitButton).toHaveAttribute('aria-busy', 'false');
        expect(form).toHaveAttribute('aria-busy', 'false');
      });
    });
  });

  describe('Criterios de aceptación - Resolución exitosa y comportamiento del formulario', () => {
    it('muestra mensaje de éxito, resetea los campos del formulario y notifica a onSuccess', async () => {
      let resolveUpload: (val: unknown) => void;
      const uploadPromise = new Promise((resolve) => {
        resolveUpload = resolve;
      });
      const uploadFn = vi.fn().mockImplementation(() => uploadPromise);
      const onSuccess = vi.fn();

      render(<MaterialUploadForm uploadFn={uploadFn} onSuccess={onSuccess} />);

      const titleInput = screen.getByTestId('upload-title-input');
      const descInput = screen.getByTestId('upload-description-input');
      const subjectInput = screen.getByTestId('upload-subject-input');
      const fileInput = screen.getByTestId(
        'upload-file-input'
      ) as HTMLInputElement;

      fireEvent.change(titleInput, {
        target: { value: 'Resumen Termodinámica' },
      });
      fireEvent.change(descInput, {
        target: { value: 'Leyes y fórmulas principales' },
      });
      fireEvent.change(subjectInput, { target: { value: 'FIS-201' } });

      const file = new File(['termo'], 'termodinamica.pdf', {
        type: 'application/pdf',
      });
      await userEvent.upload(fileInput, file);

      expect(screen.getByText(/termodinamica\.pdf/i)).toBeInTheDocument();

      const submitButton = screen.getByTestId('upload-submit-button');
      fireEvent.click(submitButton);

      expect(submitButton).toBeDisabled();
      expect(uploadFn).toHaveBeenCalledTimes(1);

      // Resolver la subida
      const responsePayload = {
        id: 'mat-termo-99',
        title: 'Resumen Termodinámica',
      };
      resolveUpload!(responsePayload);

      await waitFor(() => {
        // Alerta de éxito visible
        const successAlert = screen.getByRole('status');
        expect(successAlert).toBeInTheDocument();
        expect(successAlert).toHaveTextContent(
          '¡Material subido exitosamente!'
        );

        // No debe haber alerta de error
        expect(screen.queryByRole('alert')).not.toBeInTheDocument();

        // El formulario reinicia sus valores
        expect(titleInput).toHaveValue('');
        expect(descInput).toHaveValue('');
        expect(fileInput.value).toBe('');
        expect(
          screen.queryByText(/termodinamica\.pdf/i)
        ).not.toBeInTheDocument();
        expect(
          screen.queryByRole('button', { name: /quitar archivo/i })
        ).not.toBeInTheDocument();

        // El botón vuelve a estar habilitado
        expect(submitButton).not.toBeDisabled();
        expect(submitButton).toHaveTextContent('Subir material');

        // Callback onSuccess invocado con el payload de respuesta
        expect(onSuccess).toHaveBeenCalledWith(responsePayload);
      });
    });
  });

  describe('Casos de regresión (#244)', () => {
    it('regresión: permite quitar un archivo y seleccionar exactamente el mismo archivo nuevamente para enviarlo', async () => {
      const uploadFn = vi.fn().mockResolvedValue({ id: 'mat-regression-1' });

      render(<MaterialUploadForm uploadFn={uploadFn} />);

      fireEvent.change(screen.getByTestId('upload-title-input'), {
        target: { value: 'Guía de Álgebra Lineal' },
      });
      fireEvent.change(screen.getByTestId('upload-subject-input'), {
        target: { value: 'MAT-102' },
      });

      const file = new File(['datos binarios'], 'mismo-documento.pdf', {
        type: 'application/pdf',
      });
      const fileInput = screen.getByTestId(
        'upload-file-input'
      ) as HTMLInputElement;

      // 1. Seleccionar archivo inicialmente
      await userEvent.upload(fileInput, file);
      expect(screen.getByText(/mismo-documento\.pdf/i)).toBeInTheDocument();
      expect(fileInput.files?.[0]).toBe(file);

      // 2. Quitar archivo mediante el botón correspondiente
      const removeButton = screen.getByRole('button', {
        name: /quitar archivo/i,
      });
      fireEvent.click(removeButton);

      // El archivo debe desaparecer de la vista y limpiarse del input
      expect(
        screen.queryByText(/mismo-documento\.pdf/i)
      ).not.toBeInTheDocument();
      expect(
        screen.queryByRole('button', { name: /quitar archivo/i })
      ).not.toBeInTheDocument();
      expect(fileInput.value).toBe('');

      // 3. Volver a seleccionar exactamente la misma instancia de archivo
      await userEvent.upload(fileInput, file);
      expect(screen.getByText(/mismo-documento\.pdf/i)).toBeInTheDocument();

      // 4. Enviar el formulario y verificar que FormData incluye el archivo seleccionado
      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(uploadFn).toHaveBeenCalledTimes(1);
      });

      const formData = uploadFn.mock.calls[0][0] as FormData;
      const sentFile = formData.get('file') as File;
      expect(sentFile).toBeTruthy();
      expect(sentFile.name).toBe('mismo-documento.pdf');
    });

    it('regresión: al cambiar de tipo documento a enlace, descarta el archivo previo y no lo envía en FormData', async () => {
      const uploadFn = vi.fn().mockResolvedValue({ id: 'mat-regression-2' });

      render(<MaterialUploadForm uploadFn={uploadFn} />);

      fireEvent.change(screen.getByTestId('upload-title-input'), {
        target: { value: 'Recurso Web de Programación' },
      });
      fireEvent.change(screen.getByTestId('upload-subject-input'), {
        target: { value: 'INF-101' },
      });

      // 1. Adjuntar archivo mientras el tipo es DOCUMENT (por defecto)
      const file = new File(
        ['bytes de pdf descartable'],
        'archivo-descartado.pdf',
        {
          type: 'application/pdf',
        }
      );
      const fileInput = screen.getByTestId('upload-file-input');
      await userEvent.upload(fileInput, file);
      expect(screen.getByText(/archivo-descartado\.pdf/i)).toBeInTheDocument();

      // 2. Cambiar selector de tipo a LINK
      const typeSelect = screen.getByTestId('upload-type-select');
      fireEvent.change(typeSelect, { target: { value: 'LINK' } });

      // El input de archivo y el bloque informativo del archivo anterior deben haber desaparecido
      expect(screen.queryByTestId('upload-file-input')).not.toBeInTheDocument();
      expect(
        screen.queryByText(/archivo-descartado\.pdf/i)
      ).not.toBeInTheDocument();

      // 3. Completar enlace externo
      const linkInput = screen.getByTestId('upload-link-input');
      expect(linkInput).toBeInTheDocument();
      fireEvent.change(linkInput, {
        target: { value: 'https://ocw.mit.edu/courses/intro-to-cs' },
      });

      // 4. Enviar formulario
      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(uploadFn).toHaveBeenCalledTimes(1);
      });

      const formData = uploadFn.mock.calls[0][0] as FormData;
      expect(formData.get('type')).toBe('LINK');
      expect(formData.get('externalLink')).toBe(
        'https://ocw.mit.edu/courses/intro-to-cs'
      );

      // Comprobar estrictamente que el archivo descartado NO fue enviado en FormData
      expect(formData.has('file')).toBe(false);
      expect(formData.get('file')).toBeNull();
    });

    it('regresión: al cambiar de enlace a documento, exige un archivo y mantiene el enlace opcional en FormData', async () => {
      const uploadFn = vi.fn().mockResolvedValue({ id: 'mat-regression-3' });

      render(<MaterialUploadForm uploadFn={uploadFn} />);

      fireEvent.change(screen.getByTestId('upload-title-input'), {
        target: { value: 'Guía de Ejercicios' },
      });
      fireEvent.change(screen.getByTestId('upload-subject-input'), {
        target: { value: 'MAT-101' },
      });

      // Cambiar a LINK y escribir enlace
      const typeSelect = screen.getByTestId('upload-type-select');
      fireEvent.change(typeSelect, { target: { value: 'LINK' } });
      fireEvent.change(screen.getByTestId('upload-link-input'), {
        target: { value: 'https://example.com/material-anterior' },
      });

      // Cambiar de vuelta a DOCUMENT
      fireEvent.change(typeSelect, { target: { value: 'DOCUMENT' } });

      // Intentar enviar sin adjuntar archivo: debe bloquear y mostrar mensaje de validación
      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(
          screen.getByText('Debes seleccionar un archivo para subir.')
        ).toBeInTheDocument();
      });
      expect(uploadFn).not.toHaveBeenCalled();

      // Adjuntar archivo válido y enviar
      const file = new File(['contenido'], 'nuevo-documento.pdf', {
        type: 'application/pdf',
      });
      await userEvent.upload(screen.getByTestId('upload-file-input'), file);

      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(uploadFn).toHaveBeenCalledTimes(1);
      });

      const formData = uploadFn.mock.calls[0][0] as FormData;
      expect(formData.get('type')).toBe('DOCUMENT');
      expect(formData.has('file')).toBe(true);
      expect((formData.get('file') as File).name).toBe('nuevo-documento.pdf');
      // El contrato actual permite enviar un enlace opcional como respaldo de un archivo
      expect(formData.get('externalLink')).toBe(
        'https://example.com/material-anterior'
      );
    });
  });

  describe('Robustez de errores y validaciones adicionales', () => {
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

      const alert = await screen.findByRole('alert');
      expect(alert).toBeInTheDocument();
      expect(alert).toHaveTextContent(
        'Debes iniciar sesión para subir material. Por favor, autentícate para continuar.'
      );
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

      const alert = await screen.findByRole('alert');
      expect(alert).toBeInTheDocument();
      expect(alert).toHaveTextContent(
        'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.'
      );
    });

    it('valida campos requeridos y exige título y asignatura', async () => {
      render(<MaterialUploadForm />);

      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(
          screen.getByText('Por favor, ingresa el título del material.')
        ).toBeInTheDocument();
      });

      fireEvent.change(screen.getByTestId('upload-title-input'), {
        target: { value: 'Título presente' },
      });
      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(
          screen.getByText(
            'Por favor, ingresa el identificador de la asignatura.'
          )
        ).toBeInTheDocument();
      });
    });

    it('limpia las alertas de error previas al seleccionar un nuevo archivo en el input', async () => {
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
      const fileInput = screen.getByTestId('upload-file-input');
      await userEvent.upload(fileInput, file);

      fireEvent.click(screen.getByTestId('upload-submit-button'));

      const alert = await screen.findByRole('alert');
      expect(alert).toHaveTextContent(/15 MB/i);

      // Seleccionar un archivo diferente debe limpiar la alerta
      const newFile = new File(['small'], 'liviano.pdf', {
        type: 'application/pdf',
      });
      fireEvent.change(fileInput, {
        target: { files: [newFile] },
      });

      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    });

    it('conserva la confirmación de éxito si el callback onSuccess lanza una excepción síncrona', async () => {
      const uploadFn = vi.fn().mockResolvedValue({ id: 'form-mat-1' });
      const callbackError = new Error('Error síncrono en callback onSuccess');
      const onSuccess = vi.fn().mockImplementation(() => {
        throw callbackError;
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

      const file = new File(['content'], 'guia.pdf', {
        type: 'application/pdf',
      });
      await userEvent.upload(screen.getByTestId('upload-file-input'), file);

      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(
          screen.getByText('¡Material subido exitosamente!')
        ).toBeInTheDocument();
        expect(onSuccess).toHaveBeenCalledTimes(1);
        expect(onError).toHaveBeenCalledWith(callbackError);
      });

      // No debe mostrar alerta de error de subida
      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    });

    it('conserva la confirmación de éxito si el callback onSuccess devuelve una promesa rechazada', async () => {
      const uploadFn = vi.fn().mockResolvedValue({ id: 'form-mat-2' });
      const callbackError = new Error('Error asíncrono en callback onSuccess');
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
        target: { value: 'Guía de Estudio' },
      });
      fireEvent.change(screen.getByTestId('upload-subject-input'), {
        target: { value: 'MAT-101' },
      });

      const file = new File(['content'], 'guia.pdf', {
        type: 'application/pdf',
      });
      await userEvent.upload(screen.getByTestId('upload-file-input'), file);

      fireEvent.click(screen.getByTestId('upload-submit-button'));

      await waitFor(() => {
        expect(
          screen.getByText('¡Material subido exitosamente!')
        ).toBeInTheDocument();
        expect(onSuccess).toHaveBeenCalledTimes(1);
        expect(onError).toHaveBeenCalledWith(callbackError);
      });

      // No debe mostrar alerta de error de subida
      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    });
  });
});
