import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  SEARCH_SORT_OPTIONS,
  type SearchSort,
} from '../../domain/search/search';
import { SearchPage } from './SearchPage';

const GATEWAY = 'https://gateway.test/api/v1';
const PAGE_SIZE = 20;
const TOTAL = 41;
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

function mockPagedApi() {
  mockApi((url) => {
    const page = Number(url.searchParams.get('page'));
    return json({
      items: [result(`m-${page}`, `Página ${page}`)],
      page,
      pageSize: PAGE_SIZE,
      total: TOTAL,
    });
  });
}

function searchCalls(): URL[] {
  return fetchMock.mock.calls
    .map((call) => new URL(String(call[0])))
    .filter((url) => url.pathname.endsWith('/search'));
}

function lastCall(): URL {
  return searchCalls().at(-1)!;
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

const previousButton = () => screen.getByRole('button', { name: 'Anterior' });
const nextButton = () => screen.getByRole('button', { name: 'Siguiente' });

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
        pageSize: PAGE_SIZE,
        total: 1,
      })
    );
    renderPage();

    expect(await screen.findByText('Guía de álgebra')).toBeInTheDocument();
    expect(
      screen.getByRole('link', { name: /Guía de álgebra/ })
    ).toHaveAttribute('href', '/material/real-uuid-1');
    const [first] = searchCalls();
    expect(first.searchParams.get('q')).toBe('algebra');
    expect(first.searchParams.get('sort')).toBe('relevance');
    expect(first.searchParams.get('page')).toBe('1');
  });

  describe('paginación', () => {
    it('avanza de página pidiendo la siguiente al backend', async () => {
      mockPagedApi();
      renderPage();

      await screen.findByText('Página 1');
      await userEvent.click(nextButton());

      expect(await screen.findByText('Página 2')).toBeInTheDocument();
      expect(lastCall().searchParams.get('page')).toBe('2');
    });

    it('retrocede de página pidiendo la anterior al backend', async () => {
      mockPagedApi();
      renderPage('/search?q=algebra&page=2');

      await screen.findByText('Página 2');
      await vi.waitFor(() => expect(previousButton()).toBeEnabled());
      await userEvent.click(previousButton());

      expect(await screen.findByText('Página 1')).toBeInTheDocument();
      expect(lastCall().searchParams.get('page')).toBe('1');
      expect(screen.queryByText('Página 2')).not.toBeInTheDocument();
    });

    it('en la primera página no permite retroceder', async () => {
      mockPagedApi();
      renderPage();

      await screen.findByText('Página 1');
      expect(screen.getByText(/Página 1 de 3/)).toBeInTheDocument();
      await vi.waitFor(() => expect(nextButton()).toBeEnabled());
      expect(previousButton()).toBeDisabled();

      const callsBefore = searchCalls().length;
      await userEvent.click(previousButton());
      expect(searchCalls()).toHaveLength(callsBefore);
    });

    it('en la última página no permite avanzar', async () => {
      mockPagedApi();
      renderPage('/search?q=algebra&page=3');

      await screen.findByText('Página 3');
      expect(screen.getByText(/Página 3 de 3/)).toBeInTheDocument();
      await vi.waitFor(() => expect(previousButton()).toBeEnabled());
      expect(nextButton()).toBeDisabled();

      const callsBefore = searchCalls().length;
      await userEvent.click(nextButton());
      expect(searchCalls()).toHaveLength(callsBefore);
    });

    it('recorre ida y vuelta toda la lista respetando ambos límites', async () => {
      mockPagedApi();
      renderPage();

      await screen.findByText('Página 1');
      await vi.waitFor(() => expect(nextButton()).toBeEnabled());
      await userEvent.click(nextButton());
      await screen.findByText('Página 2');
      await vi.waitFor(() => expect(nextButton()).toBeEnabled());
      await userEvent.click(nextButton());
      await screen.findByText('Página 3');
      await vi.waitFor(() => expect(previousButton()).toBeEnabled());
      expect(nextButton()).toBeDisabled();

      await userEvent.click(previousButton());
      await screen.findByText('Página 2');
      await vi.waitFor(() => expect(previousButton()).toBeEnabled());
      await userEvent.click(previousButton());
      await screen.findByText('Página 1');
      await vi.waitFor(() => expect(nextButton()).toBeEnabled());
      expect(previousButton()).toBeDisabled();

      expect(searchCalls().map((url) => url.searchParams.get('page'))).toEqual([
        '1',
        '2',
        '3',
        '2',
        '1',
      ]);
    });
  });

  describe('ordenamiento', () => {
    it.each(SEARCH_SORT_OPTIONS.map((option) => option.value))(
      'envía sort=%s al backend y vuelve a la página 1',
      async (sort: SearchSort) => {
        mockPagedApi();
        const initial: SearchSort = sort === 'title' ? 'recent' : 'title';
        renderPage(`/search?q=algebra&sort=${initial}&page=2`);

        await screen.findByText('Página 2');
        expect(lastCall().searchParams.get('sort')).toBe(initial);
        expect(lastCall().searchParams.get('page')).toBe('2');

        await userEvent.selectOptions(
          screen.getByLabelText('Ordenar por'),
          sort
        );

        expect(await screen.findByText('Página 1')).toBeInTheDocument();
        expect(lastCall().searchParams.get('sort')).toBe(sort);
        expect(lastCall().searchParams.get('page')).toBe('1');
        expect(lastCall().searchParams.get('q')).toBe('algebra');
      }
    );

    it('ofrece exactamente las cuatro opciones de ordenamiento', () => {
      mockPagedApi();
      renderPage();
      const select = screen.getByLabelText('Ordenar por');
      const values = Array.from(
        select.querySelectorAll('option'),
        (option) => (option as HTMLOptionElement).value
      );
      expect(values).toEqual(['relevance', 'recent', 'year_desc', 'title']);
    });
  });

  it('muestra el estado vacío con el stub actual de Search', async () => {
    mockApi(() => json({ query: 'algebra', results: [], total: 0 }));
    renderPage();
    expect(await screen.findByText(/Sin resultados para/)).toBeInTheDocument();
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
