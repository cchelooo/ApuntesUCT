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

function mockApi() {
  fetchMock.mockImplementation((input: RequestInfo | URL) => {
    const { pathname } = new URL(String(input));
    if (pathname.endsWith('/search')) {
      return Promise.resolve(
        json({ items: [], page: 1, pageSize: 20, total: 0 })
      );
    }
    if (pathname.endsWith('/catalog/universities'))
      return Promise.resolve(json([{ id: 'u1', name: 'UCT' }]));
    if (pathname.endsWith('/catalog/careers'))
      return Promise.resolve(json([{ id: 'c1', name: 'Informática' }]));
    if (pathname.endsWith('/catalog/subjects'))
      return Promise.resolve(json([{ id: 's1', name: 'Álgebra', code: 'A1' }]));
    if (pathname.endsWith('/catalog/professors'))
      return Promise.resolve(json([{ id: 'p1', name: 'Ana Pérez' }]));
    return Promise.resolve(json([]));
  });
}

function lastSearch(): URL {
  return fetchMock.mock.calls
    .map((call) => new URL(String(call[0])))
    .filter((url) => url.pathname.endsWith('/search'))
    .at(-1)!;
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

describe('SearchPage: filtros académicos', () => {
  beforeEach(() => {
    fetchMock.mockReset();
    mockApi();
    vi.stubGlobal('fetch', fetchMock);
    vi.stubEnv('VITE_API_URL', GATEWAY);
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

  it('encadena universidad → carrera → asignatura → profesor y los envía a Search', async () => {
    const user = userEvent.setup();
    renderPage();

    expect(screen.getByLabelText('Carrera')).toBeDisabled();

    await screen.findByRole('option', { name: 'UCT' });
    await user.selectOptions(screen.getByLabelText('Universidad'), 'u1');
    await screen.findByRole('option', { name: 'Informática' });
    await user.selectOptions(screen.getByLabelText('Carrera'), 'c1');
    await screen.findByRole('option', { name: 'Álgebra' });
    await user.selectOptions(screen.getByLabelText('Asignatura'), 's1');
    await screen.findByRole('option', { name: 'Ana Pérez' });
    await user.selectOptions(screen.getByLabelText('Profesor'), 'p1');

    await vi.waitFor(() => {
      const params = lastSearch().searchParams;
      expect(params.get('universityId')).toBe('u1');
      expect(params.get('careerId')).toBe('c1');
      expect(params.get('subjectId')).toBe('s1');
      expect(params.get('professorId')).toBe('p1');
    });
  });

  it('reinicia los niveles inferiores al cambiar la universidad', async () => {
    const user = userEvent.setup();
    renderPage(
      '/search?q=algebra&universityId=u1&careerId=c1&subjectId=s1&professorId=p1'
    );
    await screen.findByRole('option', { name: 'UCT' });
    await user.selectOptions(screen.getByLabelText('Universidad'), '');

    await vi.waitFor(() => {
      const params = lastSearch().searchParams;
      expect(params.has('careerId')).toBe(false);
      expect(params.has('subjectId')).toBe(false);
      expect(params.has('professorId')).toBe(false);
    });
  });

  it('envía año y tipo, y valida el año', async () => {
    const user = userEvent.setup();
    renderPage();

    await user.selectOptions(screen.getByLabelText('Tipo de material'), 'EXAM');
    await vi.waitFor(() =>
      expect(lastSearch().searchParams.get('type')).toBe('EXAM')
    );

    await user.type(screen.getByLabelText('Año'), '20');
    expect(
      screen.getByText('Ingresa un año de 4 dígitos, por ejemplo 2026.')
    ).toBeInTheDocument();

    await user.type(screen.getByLabelText('Año'), '26');
    await user.click(screen.getByRole('button', { name: 'Buscar' }));
    await vi.waitFor(() =>
      expect(lastSearch().searchParams.get('year')).toBe('2026')
    );
  });

  it('limpia todos los filtros y conserva el texto buscado', async () => {
    const user = userEvent.setup();
    renderPage('/search?q=algebra&universityId=u1&year=2026&type=EXAM');

    await user.click(screen.getByRole('button', { name: 'Limpiar filtros' }));

    await vi.waitFor(() => {
      const params = lastSearch().searchParams;
      expect(params.get('q')).toBe('algebra');
      for (const key of ['universityId', 'year', 'type']) {
        expect(params.has(key)).toBe(false);
      }
    });
    expect(screen.getByLabelText('Año')).toHaveValue('');
    expect(
      screen.queryByRole('button', { name: 'Limpiar filtros' })
    ).not.toBeInTheDocument();
  });
});
