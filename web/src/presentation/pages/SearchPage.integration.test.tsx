import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, useLocation } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SearchPage } from './SearchPage';

const GATEWAY = 'https://gateway.test/api/v1';
const PAGE_SIZE = 20;
const fetchMock = vi.fn();

type SearchHandler = (url: URL) => Response | Promise<Response>;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function item(id: string, title: string) {
  return { id, title, academicYear: 2026, materialType: 'EXAM' };
}

function pageOf(
  items: unknown[],
  extra: Record<string, unknown> = {}
): Record<string, unknown> {
  return {
    results: items,
    page: 1,
    pageSize: PAGE_SIZE,
    total: items.length,
    ...extra,
  };
}

function catalogResponse(pathname: string): Response {
  if (pathname.endsWith('/catalog/universities'))
    return json([
      { id: 'u1', name: 'Universidad Uno' },
      { id: 'u2', name: 'Universidad Dos' },
    ]);
  if (pathname.endsWith('/catalog/careers'))
    return json([{ id: 'c1', name: 'Carrera Uno' }]);
  if (pathname.endsWith('/catalog/subjects'))
    return json([
      { id: 's1', name: 'Asignatura Uno', code: 'A1', semester: 1 },
    ]);
  if (pathname.endsWith('/catalog/professors'))
    return json([{ id: 'p1', name: 'Profesora Uno' }]);
  return json([]);
}

function mockBackend(search: SearchHandler) {
  fetchMock.mockImplementation((input: RequestInfo | URL) => {
    const url = new URL(String(input));
    if (url.pathname.endsWith('/search')) return Promise.resolve(search(url));
    return Promise.resolve(catalogResponse(url.pathname));
  });
}

function searchCalls(): URL[] {
  return fetchMock.mock.calls
    .map((call) => new URL(String(call[0])))
    .filter((url) => url.pathname.endsWith('/search'));
}

function lastSearch(): URL {
  return searchCalls().at(-1)!;
}

function LocationProbe() {
  const { search } = useLocation();
  return <output data-testid="location">{search}</output>;
}

function renderPage(path = '/search') {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter initialEntries={[path]}>
        <SearchPage />
        <LocationProbe />
      </MemoryRouter>
    </QueryClientProvider>
  );
}

function urlState(): URLSearchParams {
  return new URLSearchParams(screen.getByTestId('location').textContent ?? '');
}

describe('Búsqueda: integración texto + filtros + resultados', () => {
  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal('fetch', fetchMock);
    vi.stubEnv('VITE_API_URL', GATEWAY);
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

  describe('envío de parámetros', () => {
    it('al escribir y pulsar Buscar envía q con los valores por defecto y muestra los resultados', async () => {
      const user = userEvent.setup();
      mockBackend((url) =>
        json(
          pageOf([item(`id-${url.searchParams.get('q')}`, 'Guía de álgebra')])
        )
      );
      renderPage();

      expect(screen.getByText('Escribe lo que buscas')).toBeInTheDocument();
      expect(searchCalls()).toHaveLength(0);

      await user.type(screen.getByLabelText('Buscar materiales'), 'algebra');
      await user.click(screen.getByRole('button', { name: 'Buscar' }));

      expect(await screen.findByText('Guía de álgebra')).toBeInTheDocument();
      const params = lastSearch().searchParams;
      expect(params.get('q')).toBe('algebra');
      expect(params.get('sortBy')).toBe('createdAt');
      expect(params.get('order')).toBe('desc');
      expect(params.get('page')).toBe('1');
      expect(params.get('pageSize')).toBe(String(PAGE_SIZE));
      for (const key of ['universityId', 'year', 'type']) {
        expect(params.has(key)).toBe(false);
      }
      expect(urlState().get('q')).toBe('algebra');
      expect(
        screen.getByRole('link', { name: /Guía de álgebra/ })
      ).toHaveAttribute('href', '/material/id-algebra');
    });

    it('recorta los espacios del texto antes de enviarlo', async () => {
      const user = userEvent.setup();
      mockBackend(() => json(pageOf([item('m-1', 'Resultado')])));
      renderPage();

      await user.type(
        screen.getByLabelText('Buscar materiales'),
        '  calculo  '
      );
      await user.click(screen.getByRole('button', { name: 'Buscar' }));

      await screen.findByText('Resultado');
      expect(lastSearch().searchParams.get('q')).toBe('calculo');
    });

    it('combina texto, año, tipo y filtros académicos en una misma consulta', async () => {
      const user = userEvent.setup();
      mockBackend(() => json(pageOf([item('m-1', 'Resultado combinado')])));
      renderPage();

      await user.type(screen.getByLabelText('Buscar materiales'), 'algebra');
      await screen.findByRole('option', { name: 'Universidad Uno' });
      await user.selectOptions(screen.getByLabelText('Universidad'), 'u1');
      await screen.findByRole('option', { name: 'Carrera Uno' });
      await user.selectOptions(screen.getByLabelText('Carrera'), 'c1');
      await screen.findByRole('option', { name: 'Asignatura Uno' });
      await user.selectOptions(screen.getByLabelText('Asignatura'), 's1');
      await screen.findByRole('option', { name: 'Profesora Uno' });
      await user.selectOptions(screen.getByLabelText('Profesor'), 'p1');
      await user.selectOptions(
        screen.getByLabelText('Tipo de material'),
        'EXAM'
      );
      await user.type(screen.getByLabelText('Año'), '2026');
      await user.click(screen.getByRole('button', { name: 'Buscar' }));

      await vi.waitFor(() => {
        const params = lastSearch().searchParams;
        expect(params.get('q')).toBe('algebra');
        expect(params.get('universityId')).toBe('u1');
        expect(params.get('careerId')).toBe('c1');
        expect(params.get('subjectId')).toBe('s1');
        expect(params.get('professorId')).toBe('p1');
        expect(params.get('type')).toBe('EXAM');
        expect(params.get('year')).toBe('2026');
      });
      expect(
        await screen.findByText('Resultado combinado')
      ).toBeInTheDocument();
    });
  });

  describe('cambio de filtros', () => {
    it('cambiar el tipo ejecuta una nueva consulta, conserva q y vuelve a la página 1', async () => {
      const user = userEvent.setup();
      mockBackend((url) => {
        const page = Number(url.searchParams.get('page'));
        const type = url.searchParams.get('type');
        return json(
          pageOf(
            [item(`m-${page}-${type}`, `Página ${page} ${type ?? 'todos'}`)],
            {
              page,
              total: 41,
            }
          )
        );
      });
      renderPage('/search?q=algebra&page=2');

      expect(await screen.findByText('Página 2 todos')).toBeInTheDocument();
      const before = searchCalls().length;

      await user.selectOptions(
        screen.getByLabelText('Tipo de material'),
        'EXAM'
      );

      expect(await screen.findByText('Página 1 EXAM')).toBeInTheDocument();
      expect(searchCalls().length).toBeGreaterThan(before);
      const params = lastSearch().searchParams;
      expect(params.get('type')).toBe('EXAM');
      expect(params.get('q')).toBe('algebra');
      expect(params.get('page')).toBe('1');
      expect(urlState().get('type')).toBe('EXAM');
      expect(urlState().has('page')).toBe(false);
    });

    it('cambiar el orden reenvía sortBy/order y conserva los filtros activos', async () => {
      const user = userEvent.setup();
      mockBackend((url) =>
        json(pageOf([item('m-1', `Orden ${url.searchParams.get('sortBy')}`)]))
      );
      renderPage('/search?q=algebra&type=EXAM&year=2026');
      await screen.findByText('Orden createdAt');

      await user.selectOptions(screen.getByLabelText('Ordenar por'), 'title');

      expect(await screen.findByText('Orden title')).toBeInTheDocument();
      const params = lastSearch().searchParams;
      expect(params.get('sortBy')).toBe('title');
      expect(params.get('order')).toBe('asc');
      expect(params.get('q')).toBe('algebra');
      expect(params.get('type')).toBe('EXAM');
      expect(params.get('year')).toBe('2026');
    });

    it('cambiar la universidad descarta los niveles dependientes en la consulta', async () => {
      const user = userEvent.setup();
      mockBackend(() => json(pageOf([item('m-1', 'Resultado')])));
      renderPage(
        '/search?universityId=u1&careerId=c1&subjectId=s1&professorId=p1'
      );
      await screen.findByText('Resultado');
      await screen.findByRole('option', { name: 'Universidad Dos' });

      await user.selectOptions(screen.getByLabelText('Universidad'), 'u2');

      await vi.waitFor(() => {
        const params = lastSearch().searchParams;
        expect(params.get('universityId')).toBe('u2');
        for (const key of ['careerId', 'subjectId', 'professorId']) {
          expect(params.has(key)).toBe(false);
        }
      });
    });

    it('Limpiar filtros reconsulta solo con el texto', async () => {
      const user = userEvent.setup();
      mockBackend(() => json(pageOf([item('m-1', 'Resultado')])));
      renderPage('/search?q=algebra&type=EXAM&year=2026');
      await screen.findByText('Resultado');

      await user.click(screen.getByRole('button', { name: 'Limpiar filtros' }));

      await vi.waitFor(() => {
        const params = lastSearch().searchParams;
        expect(params.get('q')).toBe('algebra');
        expect(params.has('type')).toBe(false);
        expect(params.has('year')).toBe(false);
      });
    });
  });

  describe('cero resultados', () => {
    it('muestra el fallback con el texto buscado y sin tarjetas', async () => {
      const user = userEvent.setup();
      mockBackend(() => json(pageOf([], { total: 0 })));
      renderPage();

      await user.type(screen.getByLabelText('Buscar materiales'), 'xyz');
      await user.click(screen.getByRole('button', { name: 'Buscar' }));

      expect(
        await screen.findByText('Sin resultados para “xyz”')
      ).toBeInTheDocument();
      expect(
        screen.getByText('Prueba con otras palabras o revisa la ortografía.')
      ).toBeInTheDocument();
      expect(screen.getByText('0 resultados para “xyz”')).toBeInTheDocument();
      expect(screen.queryByRole('listitem')).not.toBeInTheDocument();
      expect(
        screen.queryByTestId('material-card-skeleton')
      ).not.toBeInTheDocument();
      expect(
        screen.queryByRole('button', { name: 'Siguiente' })
      ).not.toBeInTheDocument();
    });

    it('con solo filtros muestra el fallback genérico y permite seguir filtrando', async () => {
      const user = userEvent.setup();
      mockBackend((url) =>
        url.searchParams.get('type') === 'EXAM'
          ? json(pageOf([item('m-1', 'Examen encontrado')]))
          : json(pageOf([], { total: 0 }))
      );
      renderPage('/search?year=2026');

      expect(await screen.findByText('Sin resultados')).toBeInTheDocument();
      expect(screen.queryByRole('alert')).not.toBeInTheDocument();

      await user.selectOptions(
        screen.getByLabelText('Tipo de material'),
        'EXAM'
      );

      expect(await screen.findByText('Examen encontrado')).toBeInTheDocument();
      expect(screen.queryByText('Sin resultados')).not.toBeInTheDocument();
    });
  });

  describe('errores', () => {
    it('un 500 muestra una alerta, conserva el formulario y permite reintentar', async () => {
      const user = userEvent.setup();
      let failing = true;
      mockBackend(() =>
        failing ? json({}, 500) : json(pageOf([item('m-1', 'Recuperado')]))
      );
      renderPage('/search?q=algebra');

      expect(await screen.findByRole('alert')).toHaveTextContent(
        'Error temporal en el servidor. Por favor, intenta más tarde.'
      );
      // La vista sigue operativa.
      expect(screen.getByRole('search')).toBeInTheDocument();
      expect(screen.getByLabelText('Buscar materiales')).toHaveValue('algebra');
      expect(screen.getByLabelText('Tipo de material')).toBeEnabled();
      expect(screen.queryAllByTestId('material-card-skeleton')).toHaveLength(0);

      failing = false;
      await user.click(screen.getByRole('button', { name: 'Reintentar' }));

      expect(await screen.findByText('Recuperado')).toBeInTheDocument();
      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    });

    it('un fallo de red muestra el mensaje de conexión sin romper la página', async () => {
      fetchMock.mockImplementation((input: RequestInfo | URL) => {
        const url = new URL(String(input));
        if (url.pathname.endsWith('/search')) {
          return Promise.reject(new TypeError('Failed to fetch'));
        }
        return Promise.resolve(catalogResponse(url.pathname));
      });
      renderPage('/search?q=algebra');

      expect(await screen.findByRole('alert')).toHaveTextContent(
        'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.'
      );
      expect(screen.getByRole('search')).toBeInTheDocument();
      expect(
        screen.getByRole('button', { name: 'Reintentar' })
      ).toBeInTheDocument();
    });

    it('tras un error, cambiar un filtro lanza otra consulta y recupera la vista', async () => {
      const user = userEvent.setup();
      mockBackend((url) =>
        url.searchParams.get('type') === 'EXAM'
          ? json(pageOf([item('m-1', 'Examen recuperado')]))
          : json({}, 502)
      );
      renderPage('/search?q=algebra');

      expect(await screen.findByRole('alert')).toHaveTextContent(
        'Error temporal en el servidor'
      );

      await user.selectOptions(
        screen.getByLabelText('Tipo de material'),
        'EXAM'
      );

      expect(await screen.findByText('Examen recuperado')).toBeInTheDocument();
      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
      expect(lastSearch().searchParams.get('q')).toBe('algebra');
    });
  });
});
