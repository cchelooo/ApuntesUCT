import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MaterialListSection } from './MaterialListSection';

function json(body: unknown, status = 200) {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    })
  );
}

function renderSection() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter>
        <MaterialListSection pageSize={2} />
      </MemoryRouter>
    </QueryClientProvider>
  );
}

describe('MaterialListSection', () => {
  const fetchMock = vi.fn();

  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal('fetch', fetchMock);
  });
  afterEach(() => vi.unstubAllGlobals());

  it('muestra el estado de carga y luego tarjetas con IDs reales', async () => {
    fetchMock.mockReturnValueOnce(
      json({
        items: [
          { id: 'real-uuid-1', title: 'Guía 1', year: 2026, type: 'GUIDE' },
          { id: 'real-uuid-2', title: 'Prueba 2', year: 2025, type: 'EXAM' },
        ],
        page: 1,
        pageSize: 2,
        total: 2,
      })
    );
    renderSection();

    expect(screen.getByRole('status')).toHaveTextContent('Cargando materiales');
    expect(await screen.findByText('Guía 1')).toBeInTheDocument();
    expect(
      screen.getAllByRole('link').map((link) => link.getAttribute('href'))
    ).toEqual(['/material/real-uuid-1', '/material/real-uuid-2']);
    expect(String(fetchMock.mock.calls[0][0])).toContain(
      '/materials?page=1&pageSize=2'
    );
  });

  it('muestra la lista vacía', async () => {
    fetchMock.mockReturnValueOnce(
      json({ items: [], page: 1, pageSize: 2, total: 0 })
    );
    renderSection();
    expect(
      await screen.findByText('Aún no hay materiales')
    ).toBeInTheDocument();
  });

  it('muestra el error y permite reintentar', async () => {
    fetchMock.mockReturnValueOnce(json({}, 500));
    renderSection();
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Error temporal en el servidor'
    );

    fetchMock.mockReturnValueOnce(
      json({
        items: [{ id: 'a1', title: 'Resumen' }],
        page: 1,
        pageSize: 2,
        total: 1,
      })
    );
    await userEvent.click(screen.getByRole('button', { name: 'Reintentar' }));
    expect(await screen.findByText('Resumen')).toBeInTheDocument();
  });

  it('pagina con page/pageSize del backend', async () => {
    fetchMock
      .mockReturnValueOnce(
        json({
          items: [{ id: 'p1', title: 'Página uno' }],
          page: 1,
          pageSize: 2,
          total: 3,
        })
      )
      .mockReturnValueOnce(
        json({
          items: [{ id: 'p3', title: 'Página dos' }],
          page: 2,
          pageSize: 2,
          total: 3,
        })
      );
    renderSection();

    await screen.findByText('Página uno');
    expect(screen.getByText(/Página 1 de 2/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Anterior' })).toBeDisabled();

    await userEvent.click(screen.getByRole('button', { name: 'Siguiente' }));
    await waitFor(() =>
      expect(String(fetchMock.mock.calls[1][0])).toContain('page=2&pageSize=2')
    );
    expect(await screen.findByText('Página dos')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Siguiente' })).toBeDisabled();
  });
});
