// @vitest-environment jsdom

import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { MaterialUploadForm } from './MaterialUploadForm';
import { MaterialRequestError } from '../../../infrastructure/material/materialApi';

describe('MaterialUploadForm', () => {
  const mockUploadFn = vi.fn();
  const mockSuccessCallback = vi.fn();
  const mockErrorCallback = vi.fn();

  beforeEach(() => {
    mockUploadFn.mockReset();
    mockSuccessCallback.mockReset();
    mockErrorCallback.mockReset();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  const renderComponent = (props = {}) => {
    return render(
      <MaterialUploadForm
        uploadFn={mockUploadFn}
        onSuccess={mockSuccessCallback}
        onError={mockErrorCallback}
        {...props}
      />
    );
  };

  describe('1. Selección de archivo', () => {
    it('permite seleccionar un archivo y refleja su nombre en la interfaz', async () => {
      const user = userEvent.setup();
      renderComponent();

      const file = new File(['contenido de prueba'], 'guia-calculo.pdf', {
        type: 'application/pdf',
      });

      const fileInput = screen.getByLabelText('Archivo');
      await user.upload(fileInput, file);

      expect(screen.getByText(/guia-calculo\.pdf/i)).toBeInTheDocument();
    });

    it('permite quitar el archivo seleccionado mediante el botón Quitar', async () => {
      const user = userEvent.setup();
      renderComponent();

      const file = new File(['contenido'], 'resumen.docx', {
        type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      });

      const fileInput = screen.getByLabelText('Archivo');
      await user.upload(fileInput, file);

      expect(screen.getByText(/resumen\.docx/i)).toBeInTheDocument();

      const removeButton = screen.getByRole('button', { name: /Quitar/i });
      await user.click(removeButton);

      expect(screen.queryByText(/resumen\.docx/i)).not.toBeInTheDocument();
      expect(
        screen.getByText(/Formatos permitidos: PDF, Word/i)
      ).toBeInTheDocument();
    });
  });

  describe('2. Envío correcto de metadatos', () => {
    it('envía los metadatos completos y el archivo al cliente de materiales', async () => {
      const user = userEvent.setup();
      mockUploadFn.mockResolvedValueOnce({
        status: 'success',
        message: 'Material registrado exitosamente en estado PENDING_REVIEW.',
        data: {
          id: 'mat-1',
          title: 'Guía de Ecuaciones Diferenciales',
          year: '2026',
          type: 'DOCUMENT',
          status: 'PENDING_REVIEW',
          subjectId: 'MAT-301',
        },
      });

      renderComponent();

      const file = new File(['datos'], 'ecuaciones.pdf', {
        type: 'application/pdf',
      });

      await user.type(
        screen.getByLabelText(/Título del material/i),
        'Guía de Ecuaciones Diferenciales'
      );
      await user.selectOptions(
        screen.getByLabelText(/Tipo de material/i),
        'DOCUMENT'
      );

      const yearInput = screen.getByLabelText(/Año académico/i);
      await user.clear(yearInput);
      await user.type(yearInput, '2026');

      await user.type(
        screen.getByLabelText(/Asignatura \(ID o código\)/i),
        'MAT-301'
      );
      await user.type(screen.getByLabelText(/Carrera \(opcional\)/i), 'INF-02');
      await user.type(
        screen.getByLabelText(/Profesor \(opcional\)/i),
        'PROF-05'
      );
      await user.type(
        screen.getByLabelText(/Descripción \(opcional\)/i),
        'Ejercicios prácticos con soluciones'
      );

      const fileInput = screen.getByLabelText('Archivo');
      await user.upload(fileInput, file);

      const submitButton = screen.getByRole('button', {
        name: /Subir material/i,
      });
      await user.click(submitButton);

      await waitFor(() => {
        expect(mockUploadFn).toHaveBeenCalledTimes(1);
      });

      expect(mockUploadFn).toHaveBeenCalledWith({
        title: 'Guía de Ecuaciones Diferenciales',
        description: 'Ejercicios prácticos con soluciones',
        year: '2026',
        type: 'DOCUMENT',
        subjectId: 'MAT-301',
        careerId: 'INF-02',
        professorId: 'PROF-05',
        externalLink: undefined,
        file,
      });
    });

    it('valida que se completen los campos obligatorios antes de enviar', async () => {
      const user = userEvent.setup();
      renderComponent();

      // Dejamos el título vacío y no seleccionamos archivo
      const submitButton = screen.getByRole('button', {
        name: /Subir material/i,
      });
      await user.click(submitButton);

      expect(mockUploadFn).not.toHaveBeenCalled();
      expect(
        screen.getByText('Por favor, completa todos los campos obligatorios.')
      ).toBeInTheDocument();
    });

    it('valida que se seleccione un archivo cuando el tipo de material no es LINK', async () => {
      const user = userEvent.setup();
      renderComponent();

      await user.type(
        screen.getByLabelText(/Título del material/i),
        'Apunte de Sistemas'
      );
      await user.type(
        screen.getByLabelText(/Asignatura \(ID o código\)/i),
        'SIS-101'
      );

      const submitButton = screen.getByRole('button', {
        name: /Subir material/i,
      });
      await user.click(submitButton);

      expect(mockUploadFn).not.toHaveBeenCalled();
      expect(
        screen.getByText(
          'Debes seleccionar un archivo para subir este material.'
        )
      ).toBeInTheDocument();
    });

    it('permite enviar sin archivo cuando el tipo es LINK y valida enlace externo', async () => {
      const user = userEvent.setup();
      mockUploadFn.mockResolvedValueOnce({
        status: 'success',
        message: 'Material registrado.',
        data: { id: 'link-1' },
      });

      renderComponent();

      await user.type(
        screen.getByLabelText(/Título del material/i),
        'Video Clase Redes'
      );
      await user.selectOptions(
        screen.getByLabelText(/Tipo de material/i),
        'LINK'
      );
      await user.type(
        screen.getByLabelText(/Asignatura \(ID o código\)/i),
        'NET-101'
      );

      // Intento enviar sin enlace externo
      const submitButton = screen.getByRole('button', {
        name: /Subir material/i,
      });
      await user.click(submitButton);

      expect(mockUploadFn).not.toHaveBeenCalled();
      expect(
        screen.getByText(
          'Debes ingresar un enlace externo para este tipo de material.'
        )
      ).toBeInTheDocument();

      // Completamos enlace externo
      await user.type(
        screen.getByLabelText(/Enlace externo/i),
        'https://drive.google.com/file/d/xyz'
      );
      await user.click(submitButton);

      await waitFor(() => {
        expect(mockUploadFn).toHaveBeenCalledTimes(1);
      });

      expect(mockUploadFn).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'LINK',
          externalLink: 'https://drive.google.com/file/d/xyz',
          file: null,
        })
      );
    });
  });

  describe('3. Manejo y visualización de errores específicos (códigos 413 y 415)', () => {
    it('maneja y visualiza el error 413 (Payload Too Large) con el mensaje mapeado correspondiente', async () => {
      const user = userEvent.setup();
      mockUploadFn.mockRejectedValueOnce(
        new MaterialRequestError('Payload Too Large', { status: 413 })
      );

      renderComponent();

      const file = new File(['archivo gigante'], 'libro-pesado.pdf', {
        type: 'application/pdf',
      });

      await user.type(
        screen.getByLabelText(/Título del material/i),
        'Libro Completo'
      );
      await user.type(
        screen.getByLabelText(/Asignatura \(ID o código\)/i),
        'MAT-101'
      );
      await user.upload(screen.getByLabelText('Archivo'), file);

      await user.click(screen.getByRole('button', { name: /Subir material/i }));

      const alert = await screen.findByRole('alert');
      expect(alert).toHaveTextContent(
        'El archivo es demasiado grande. Por favor, selecciona un archivo de menor tamaño.'
      );
      expect(mockErrorCallback).toHaveBeenCalledTimes(1);

      // El botón debe rehabilitarse para permitir otro intento
      expect(
        screen.getByRole('button', { name: /Subir material/i })
      ).toBeEnabled();
    });

    it('maneja y visualiza el error 415 (Unsupported Media Type) con el mensaje mapeado correspondiente', async () => {
      const user = userEvent.setup();
      mockUploadFn.mockRejectedValueOnce(
        new MaterialRequestError('Unsupported Media Type', { status: 415 })
      );

      renderComponent();

      const file = new File(['binario'], 'ejecutable.exe', {
        type: 'application/octet-stream',
      });

      await user.type(
        screen.getByLabelText(/Título del material/i),
        'Archivo No Admitido'
      );
      await user.type(
        screen.getByLabelText(/Asignatura \(ID o código\)/i),
        'MAT-101'
      );
      fireEvent.change(screen.getByLabelText('Archivo'), {
        target: { files: [file] },
      });

      await user.click(screen.getByRole('button', { name: /Subir material/i }));

      const alert = await screen.findByRole('alert');
      expect(alert).toHaveTextContent(
        'El formato del archivo no es soportado. Por favor, utiliza un formato válido.'
      );
      expect(mockErrorCallback).toHaveBeenCalledTimes(1);

      expect(
        screen.getByRole('button', { name: /Subir material/i })
      ).toBeEnabled();
    });

    it('maneja y visualiza error de conexión a internet', async () => {
      const user = userEvent.setup();
      mockUploadFn.mockRejectedValueOnce(
        new MaterialRequestError('Fallo de red', { isNetworkError: true })
      );

      renderComponent();

      const file = new File(['datos'], 'apunte.pdf', {
        type: 'application/pdf',
      });

      await user.type(
        screen.getByLabelText(/Título del material/i),
        'Apunte Redes'
      );
      await user.type(
        screen.getByLabelText(/Asignatura \(ID o código\)/i),
        'RED-101'
      );
      await user.upload(screen.getByLabelText('Archivo'), file);

      await user.click(screen.getByRole('button', { name: /Subir material/i }));

      const alert = await screen.findByRole('alert');
      expect(alert).toHaveTextContent(
        'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.'
      );
    });
  });

  describe('4. Estados de carga (loading) y éxito', () => {
    it('muestra el estado de carga (loading), deshabilita el botón y evita doble envío', async () => {
      let resolvePromise!: (value: unknown) => void;
      const delayedPromise = new Promise((resolve) => {
        resolvePromise = resolve;
      });
      mockUploadFn.mockReturnValueOnce(delayedPromise);

      renderComponent();

      const file = new File(['datos'], 'apunte.pdf', {
        type: 'application/pdf',
      });

      // Llenamos el formulario usando fireEvent para control directo
      fireEvent.change(screen.getByLabelText(/Título del material/i), {
        target: { value: 'Apunte en carga' },
      });
      fireEvent.change(screen.getByLabelText(/Asignatura \(ID o código\)/i), {
        target: { value: 'MAT-101' },
      });
      fireEvent.change(screen.getByLabelText('Archivo'), {
        target: { files: [file] },
      });

      const submitButton = screen.getByRole('button', {
        name: /Subir material/i,
      });
      fireEvent.click(submitButton);

      // Verificamos estado de carga
      expect(
        screen.getByRole('button', { name: /Subiendo material\.\.\./i })
      ).toBeDisabled();
      expect(screen.getByLabelText(/Título del material/i)).toBeDisabled();

      // Intentamos clickear nuevamente mientras está en carga
      fireEvent.click(
        screen.getByRole('button', { name: /Subiendo material\.\.\./i })
      );
      expect(mockUploadFn).toHaveBeenCalledTimes(1);

      // Completamos la respuesta
      resolvePromise({
        status: 'success',
        message: 'Completado.',
        data: { id: 'mat-ok' },
      });

      await waitFor(() => {
        expect(
          screen.getByRole('button', { name: /Subir material/i })
        ).toBeEnabled();
      });
    });

    it('muestra el estado de éxito, resetea los campos e invoca onSuccess', async () => {
      const user = userEvent.setup();
      const mockSuccessData = {
        status: 'success',
        message: 'Material registrado exitosamente en estado PENDING_REVIEW.',
        data: { id: 'mat-exito-99', title: 'Apunte Final' },
      };
      mockUploadFn.mockResolvedValueOnce(mockSuccessData);

      renderComponent();

      const file = new File(['datos'], 'apunte-final.pdf', {
        type: 'application/pdf',
      });

      await user.type(
        screen.getByLabelText(/Título del material/i),
        'Apunte Final'
      );
      await user.type(
        screen.getByLabelText(/Asignatura \(ID o código\)/i),
        'MAT-200'
      );
      await user.upload(screen.getByLabelText('Archivo'), file);

      await user.click(screen.getByRole('button', { name: /Subir material/i }));

      // Estado de éxito
      const statusAlert = await screen.findByRole('status');
      expect(statusAlert).toHaveTextContent('Material subido exitosamente.');

      // Callback onSuccess
      expect(mockSuccessCallback).toHaveBeenCalledWith(mockSuccessData);

      // Formulario reseteado
      expect(screen.getByLabelText(/Título del material/i)).toHaveValue('');
      expect(screen.queryByText(/apunte-final\.pdf/i)).not.toBeInTheDocument();
    });
  });
});
