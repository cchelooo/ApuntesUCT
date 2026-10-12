import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { MaterialUploadPage } from './MaterialUploadPage';

let client: QueryClient;

beforeEach(() => {
  client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  vi.stubGlobal(
    'fetch',
    vi.fn(async (input: string) => {
      const resource = new URL(input).pathname.split('/').at(-1);
      const data: Record<string, unknown[]> = {
        universities: [
          { id: 'u1', name: 'Universidad Católica de Temuco' },
          { id: 'u2', name: 'Otra universidad' },
        ],
        careers: [{ id: 'c1', name: 'Ingeniería Informática' }],
        subjects: [
          {
            id: 's1',
            name: 'Álgebra',
            code: 'ALG',
            semester: 1,
            active: true,
            careerId: 'c1',
          },
        ],
        professors: [{ id: 'p1', name: 'Ana Pérez' }],
      };
      return {
        ok: true,
        json: async () => data[resource ?? ''] ?? [],
      } as Response;
    })
  );
});

afterEach(() => {
  client.clear();
  vi.unstubAllGlobals();
});

function setup() {
  const user = userEvent.setup();
  render(
    <QueryClientProvider client={client}>
      <MemoryRouter>
        <MaterialUploadPage />
      </MemoryRouter>
    </QueryClientProvider>
  );
  return user;
}

async function fillMetadata(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByLabelText('Título'), 'Guía de álgebra');
  await user.type(
    screen.getByLabelText(/Descripción/),
    'Ejercicios de matrices'
  );
  await user.type(screen.getByLabelText('Año'), '2026');
  await screen.findByRole('option', { name: 'Universidad Católica de Temuco' });
  await user.selectOptions(screen.getByLabelText('Universidad'), 'u1');
  await screen.findByRole('option', { name: 'Ingeniería Informática' });
  await user.selectOptions(screen.getByLabelText('Carrera'), 'c1');
  await screen.findByRole('option', { name: 'Álgebra' });
  await user.selectOptions(screen.getByLabelText('Asignatura'), 's1');
}

describe('Formulario de subida de material', () => {
  it('permite completar metadatos y revisar un archivo sin publicar', async () => {
    const user = setup();
    expect(
      screen.getByRole('button', { name: 'Revisar material' })
    ).toBeDisabled();
    await fillMetadata(user);
    await screen.findByRole('option', { name: 'Ana Pérez' });
    await user.selectOptions(screen.getByLabelText('Profesor'), 'p1');
    await user.selectOptions(
      screen.getByLabelText('Tipo de material'),
      'SUMMARY'
    );
    const file = new File(['apuntes'], 'resumen.pdf', {
      type: 'application/pdf',
    });
    await user.upload(screen.getByLabelText('Selecciona tu archivo'), file);
    expect(screen.getByText(/Máximo 15 MB/)).toBeInTheDocument();
    // JSDOM no refleja user.upload en la validación nativa de file.required.
    // La validación y el clic real se comprueban también en navegador.
    fireEvent.submit(
      screen.getByRole('button', { name: 'Revisar material' }).closest('form')!
    );
    const review = within(
      screen.getByRole('region', { name: 'Revisa tu material' })
    );
    for (const value of [
      'Guía de álgebra',
      'Ejercicios de matrices',
      'Universidad Católica de Temuco',
      'Ingeniería Informática',
      'Álgebra',
      'Ana Pérez',
      '2026',
      'Resumen',
      'resumen.pdf',
    ]) {
      expect(review.getByText(value)).toBeInTheDocument();
    }
    await waitFor(() =>
      expect(
        screen.getByRole('heading', { name: 'Revisa tu material' })
      ).toHaveFocus()
    );
    expect(
      review.getByText(/aún no se ha publicado ni guardado/)
    ).toBeInTheDocument();
    expect(
      vi
        .mocked(fetch)
        .mock.calls.every(([url]) => String(url).includes('/catalog/'))
    ).toBe(true);
    await user.type(screen.getByLabelText('Título'), ' actualizado');
    expect(
      screen.queryByRole('region', { name: 'Revisa tu material' })
    ).not.toBeInTheDocument();
  });

  it('cambia a enlace y elimina el archivo previo al volver a documento', async () => {
    const user = setup();
    await fillMetadata(user);
    await user.upload(
      screen.getByLabelText('Selecciona tu archivo'),
      new File(['pdf'], 'guia.pdf', { type: 'application/pdf' })
    );
    await user.selectOptions(screen.getByLabelText('Tipo de material'), 'LINK');
    expect(
      screen.queryByLabelText('Selecciona tu archivo')
    ).not.toBeInTheDocument();
    await user.type(
      screen.getByLabelText('Enlace'),
      'https://example.com/material'
    );
    await user.click(screen.getByRole('button', { name: 'Revisar material' }));
    expect(
      within(
        screen.getByRole('region', { name: 'Revisa tu material' })
      ).getByText('https://example.com/material')
    ).toBeInTheDocument();
    await user.selectOptions(
      screen.getByLabelText('Tipo de material'),
      'DOCUMENT'
    );
    expect(screen.queryByLabelText('Enlace')).not.toBeInTheDocument();
    expect(
      (screen.getByLabelText('Selecciona tu archivo') as HTMLInputElement).files
    ).toHaveLength(0);
    expect(
      screen.queryByRole('region', { name: 'Revisa tu material' })
    ).not.toBeInTheDocument();
  });

  it('permite quitar, volver a seleccionar y reemplazar un archivo', async () => {
    const user = setup();
    const input = screen.getByLabelText(
      'Selecciona tu archivo'
    ) as HTMLInputElement;
    const file = new File(['pdf'], 'guia.pdf', { type: 'application/pdf' });
    await user.upload(input, file);
    await user.click(screen.getByRole('button', { name: 'Quitar archivo' }));
    expect(input.files).toHaveLength(0);
    expect(input).toHaveFocus();
    await user.upload(input, file);
    expect(input.files?.[0]).toBe(file);
    const replacement = new File(['nuevo'], 'nuevo.pdf', {
      type: 'application/pdf',
    });
    await user.upload(input, replacement);
    expect(input.files?.[0]).toBe(replacement);
  });

  it('limpia la selección dependiente al cambiar universidad', async () => {
    const user = setup();
    await fillMetadata(user);
    await user.selectOptions(screen.getByLabelText('Universidad'), 'u2');
    expect(screen.getByLabelText('Carrera')).toHaveValue('');
    expect(screen.getByLabelText('Asignatura')).toBeDisabled();
    expect(screen.getByLabelText('Profesor')).toBeDisabled();
    expect(
      screen.getByRole('button', { name: 'Revisar material' })
    ).toBeDisabled();
  });

  it('informa errores de catálogo y no permite revisar datos incompletos', async () => {
    vi.mocked(fetch).mockRejectedValue(new Error('Sin conexión'));
    setup();
    expect(
      await screen.findByText(/problema al cargar los datos del catálogo/)
    ).toBeInTheDocument();
    expect(screen.getByLabelText('Universidad')).toBeDisabled();
    expect(
      screen.getByRole('button', { name: 'Revisar material' })
    ).toBeDisabled();
  });
});
