// @vitest-environment jsdom

import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MaterialForm } from './MaterialForm';
import { MaterialRequestError } from '../../../infrastructure/material/materialApi';

describe('MaterialForm (Alias / Re-export)', () => {
  const mockUploadFn = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('permite seleccionar un archivo y enviar metadatos correctamente', async () => {
    const user = userEvent.setup();
    mockUploadFn.mockResolvedValueOnce({
      status: 'success',
      message: 'OK',
      data: { id: '1' },
    });

    render(<MaterialForm uploadFn={mockUploadFn} />);

    const file = new File(['test'], 'archivo.pdf', { type: 'application/pdf' });
    await user.upload(screen.getByLabelText('Archivo'), file);
    expect(screen.getByText(/archivo\.pdf/i)).toBeInTheDocument();

    await user.type(
      screen.getByLabelText(/Título del material/i),
      'Título Test'
    );
    await user.type(
      screen.getByLabelText(/Asignatura \(ID o código\)/i),
      'MAT-101'
    );

    await user.click(screen.getByRole('button', { name: /Subir material/i }));

    await waitFor(() => {
      expect(mockUploadFn).toHaveBeenCalledTimes(1);
    });
  });

  it('muestra errores 413 y 415 a través de MaterialForm', async () => {
    const user = userEvent.setup();
    mockUploadFn.mockRejectedValueOnce(
      new MaterialRequestError('413', { status: 413 })
    );

    render(<MaterialForm uploadFn={mockUploadFn} />);

    const file = new File(['test'], 'archivo.pdf', { type: 'application/pdf' });
    await user.upload(screen.getByLabelText('Archivo'), file);
    await user.type(
      screen.getByLabelText(/Título del material/i),
      'Título Test'
    );
    await user.type(
      screen.getByLabelText(/Asignatura \(ID o código\)/i),
      'MAT-101'
    );

    await user.click(screen.getByRole('button', { name: /Subir material/i }));

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent(
      'El archivo es demasiado grande. Por favor, selecciona un archivo de menor tamaño.'
    );
  });
});
