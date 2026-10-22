import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SearchPage } from './SearchPage';

const GATEWAY = 'https://gateway.test/api/v1';
const fetchMock = vi.fn();

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function result(materialId: string, title: string) {
  return { materialId, title, academicYear: 2026, materialType: 'EXAM' };
}

function mockApi(search: (url: URL) => Response) {
  fetchMock.mockImplementation((input: RequestInfo | URL) => {
    const url = new URL(String(input));
    if (url.pathname.endsWith('/search')) return Promise.resolve(search(url));
    return Promise.resolve(json([]));
  });
}

function searchCalls(): URL[] {
  return fetchMock.mock.calls
    .map((call) => new URL(String(call[0])))
    .filter((url) => url.pathname.endsWith('/search'));
}

function renderPage(path = '/search?q=algebra') {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter initialEntries={[path]}>
        <SearchPage />
      </MemoryRouter>
    </QueryClientProvider>
  );
}

describe('SearchPage', () => {
  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal('fetch', fetchMock);
    vi.stubEnv('VITE_API_URL', GATEWAY);
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

  it('no consulta al backend sin término de búsqueda', () => {
    renderPage('/search');
    expect(screen.getByText('Escribe lo que buscas')).toBeInTheDocument();
    expect(searchCalls()).toHaveLength(0);
  });

  it('muestra los resultados enlazando al materialId real', async () => {
    mockApi(() =>
      json({
        items: [result('real-uuid-1', 'Guía de álgebra')],
        page: 1,
        pageSize: 20,
        total: 1,
      })
    );
    renderPage();

    expect(await screen.findByText('Guía de álgebra')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Guía de álgebra/ })).toHaveAttribute(
      'href',
      '/material/real-uuid-1'
    );
    const [first] = searchCalls();
    expect(first.searchParams.get('q')).toBe('algebra');
    expect(first.searchParams.get('sort')).toBe('relevance');
    expect(first.searchParams.get('page')).toBe('1');
  });

  it('envía el criterio de ordenamiento elegido al backend y vuelve a la página 1', async () => {
    mockApi(() =>
      json({ items: [result('a', 'Uno')], page: 1, pageSize: 20, total: 1 })
    );
    renderPage('/search?q=algebra&page=2');
    await screen.findByText('Uno');

    await userEvent.selectOptions(screen.getByLabelText('Ordenar por'), 'recent');

    await vi.waitFor(() => {
      const last = searchCalls().at(-1)!;
      expect(last.searchParams.get('sort')).toBe('recent');
      expect(last.searchParams.get('page')).toBe('1');
    });
  });

  it('avanza de página pidiendo la siguiente al backend', async () => {
    mockApi((url) =>
      url.searchParams.get('page') === '2'
        ? json({
            items: [result('p2', 'Página dos')],
            page: 2,
            pageSize: 20,
            total: 21,
          })
        : json({
            items: [result('p1', 'Página uno')],
            page: 1,
            pageSize: 20,
            total: 21,
          })
    );
    renderPage();

    await screen.findByText('Página uno');
    expect(screen.getByRole('button', { name: 'Anterior' })).toBeDisabled();

    await userEvent.click(screen.getByRole('button', { name: 'Siguiente' }));

    expect(await screen.findByText('Página dos')).toBeInTheDocument();
    expect(searchCalls().at(-1)!.searchParams.get('page')).toBe('2');
  });

  it('muestra el estado vacío con el stub actual de Search', async () => {
    mockApi(() => json({ query: 'algebra', results: [], total: 0 }));
    renderPage();
    expect(
      await screen.findByText(/Sin resultados para/)
    ).toBeInTheDocument();
  });

  it('muestra el error y permite reintentar', async () => {
    let attempts = 0;
    mockApi(() => {
      attempts += 1;
      return attempts === 1
        ? json({}, 502)
        : json({ items: [result('a', 'Recuperado')], total: 1 });
    });
    renderPage();

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Error temporal en el servidor'
    );
    await userEvent.click(screen.getByRole('button', { name: 'Reintentar' }));
    expect(await screen.findByText('Recuperado')).toBeInTheDocument();
  });
});