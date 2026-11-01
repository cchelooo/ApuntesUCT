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
        json({
          results: [{ id: 'm-1', title: 'Resultado', academicYear: 2026 }],
          page: 1,
          pageSize: 20,
          total: 1,
        })
      );
    }
    if (pathname.endsWith('/catalog/universities'))
      return Promise.resolve(
        json([
          { id: 'u1', name: 'Universidad Uno' },
          { id: 'u2', name: 'Universidad Dos' },
        ])
      );
    if (pathname.endsWith('/catalog/careers'))
      return Promise.resolve(json([{ id: 'c1', name: 'Carrera Uno' }]));
    if (pathname.endsWith('/catalog/subjects'))
      return Promise.resolve(
        json([{ id: 's1', name: 'Asignatura Uno', code: 'A1', semester: 1 }])
      );
    if (pathname.endsWith('/catalog/professors'))
      return Promise.resolve(json([{ id: 'p1', name: 'Profesora Uno' }]));
    return Promise.resolve(json([]));
  });
}

function searchCalls(): URL[] {
  return fetchMock.mock.calls
    .map((call) => new URL(String(call[0])))
    .filter((url) => url.pathname.endsWith('/search'));
}

function catalogCalls(resource: string): URL[] {
  return fetchMock.mock.calls
    .map((call) => new URL(String(call[0])))
    .filter((url) => url.pathname.endsWith(`/catalog/${resource}`));
}

function renderPage(path: string) {
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

  it('encadena Universidad → Carrera → Asignatura → Profesor y envía los IDs a Search', async () => {
    const user = userEvent.setup();
    renderPage('/search');

    await screen.findByRole('option', { name: 'Universidad Uno' });
    expect(screen.getByLabelText('Carrera')).toBeDisabled();

    await user.selectOptions(screen.getByLabelText('Universidad'), 'u1');
    await screen.findByRole('option', { name: 'Carrera Uno' });
    expect(
      catalogCalls('careers').at(-1)!.searchParams.get('universityId')
    ).toBe('u1');

    await user.selectOptions(screen.getByLabelText('Carrera'), 'c1');
    await screen.findByRole('option', { name: 'Asignatura Uno' });
    expect(catalogCalls('subjects').at(-1)!.searchParams.get('careerId')).toBe(
      'c1'
    );

    await user.selectOptions(screen.getByLabelText('Asignatura'), 's1');
    await screen.findByRole('option', { name: 'Profesora Uno' });
    expect(
      catalogCalls('professors').at(-1)!.searchParams.get('subjectId')
    ).toBe('s1');

    await user.selectOptions(screen.getByLabelText('Profesor'), 'p1');
    await screen.findByText('Resultado');

    const last = searchCalls().at(-1)!;
    expect(last.searchParams.get('universityId')).toBe('u1');
    expect(last.searchParams.get('careerId')).toBe('c1');
    expect(last.searchParams.get('subjectId')).toBe('s1');
    expect(last.searchParams.get('professorId')).toBe('p1');
    expect(last.searchParams.has('q')).toBe(false);
  });

  it('cambiar la universidad reinicia carrera, asignatura y profesor en la búsqueda', async () => {
    const user = userEvent.setup();
    renderPage(
      '/search?universityId=u1&careerId=c1&subjectId=s1&professorId=p1'
    );
    await screen.findByText('Resultado');
    await screen.findByRole('option', { name: 'Universidad Dos' });

    await user.selectOptions(screen.getByLabelText('Universidad'), 'u2');

    await vi.waitFor(() => {
      const last = searchCalls().at(-1)!;
      expect(last.searchParams.get('universityId')).toBe('u2');
      for (const key of ['careerId', 'subjectId', 'professorId']) {
        expect(last.searchParams.has(key)).toBe(false);
      }
    });
  });

  it('envía Año y Tipo a Search Service', async () => {
    const user = userEvent.setup();
    renderPage('/search?q=algebra');
    await screen.findByText('Resultado');

    await user.selectOptions(screen.getByLabelText('Tipo de material'), 'EXAM');
    await user.type(screen.getByLabelText('Año'), '2026');
    await user.click(screen.getByRole('button', { name: 'Buscar' }));

    await vi.waitFor(() => {
      const last = searchCalls().at(-1)!;
      expect(last.searchParams.get('type')).toBe('EXAM');
      expect(last.searchParams.get('year')).toBe('2026');
      expect(last.searchParams.get('q')).toBe('algebra');
    });
  });

  it('rechaza un año fuera de rango sin consultar al backend', async () => {
    const user = userEvent.setup();
    renderPage('/search?q=algebra');
    await screen.findByText('Resultado');
    const before = searchCalls().length;

    await user.type(screen.getByLabelText('Año'), '1800');
    await user.click(screen.getByRole('button', { name: 'Buscar' }));

    expect(
      await screen.findByText('El año debe estar entre 1900 y 2099.')
    ).toBeInTheDocument();
    expect(searchCalls()).toHaveLength(before);
  });

  it('Limpiar filtros quita academia, año y tipo y conserva el texto', async () => {
    const user = userEvent.setup();
    renderPage(
      '/search?q=algebra&universityId=u1&careerId=c1&year=2026&type=EXAM'
    );
    await screen.findByText('Resultado');

    await user.click(screen.getByRole('button', { name: 'Limpiar filtros' }));

    await vi.waitFor(() => {
      const last = searchCalls().at(-1)!;
      expect(last.searchParams.get('q')).toBe('algebra');
      for (const key of ['universityId', 'careerId', 'year', 'type']) {
        expect(last.searchParams.has(key)).toBe(false);
      }
    });
    expect(screen.getByLabelText('Universidad')).toHaveValue('');
    expect(screen.getByLabelText('Año')).toHaveValue('');
    expect(screen.getByLabelText('Tipo de material')).toHaveValue('');
    expect(
      screen.queryByRole('button', { name: 'Limpiar filtros' })
    ).not.toBeInTheDocument();
  });

  it('solo con filtros y sin texto muestra el estado inicial al limpiarlos', async () => {
    const user = userEvent.setup();
    renderPage('/search?year=2026');
    await screen.findByText('Resultado');

    await user.click(screen.getByRole('button', { name: 'Limpiar filtros' }));

    expect(
      await screen.findByText('Escribe lo que buscas')
    ).toBeInTheDocument();
  });
});
