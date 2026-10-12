import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MaterialDetailRoute } from './MaterialDetailRoute';

const fetchMock = vi.fn();

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function mockApi(detail: () => Response) {
  fetchMock.mockImplementation((input: RequestInfo | URL) => {
    const { pathname } = new URL(String(input));
    if (/\/materials\/[^/]+$/.test(pathname)) return Promise.resolve(detail());
    return Promise.resolve(json([]));
  });
}

function renderRoute(path: string) {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter initialEntries={[path]}>
        <Routes>
          <Route
            path="/material/:materialId"
            element={<MaterialDetailRoute />}
          />
          <Route path="/catalog" element={<p>Catálogo</p>} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>
  );
}

describe('MaterialDetailRoute', () => {
  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal('fetch', fetchMock);
  });
  afterEach(() => vi.unstubAllGlobals());

  it('consume GET /materials/:id y habilita la descarga por el Gateway', async () => {
    mockApi(() =>
      json({
        id: 'abc-123',
        title: 'Certamen 1',
        academicYear: 2026,
        materialType: 'EXAM',
        versions: [
          { versionNumber: 1, mimeType: 'application/pdf', fileSize: '2048' },
        ],
      })
    );
    renderRoute('/material/abc-123');

    expect(await screen.findByText('Certamen 1')).toBeInTheDocument();
    expect(screen.getByText('PDF')).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: /descargar material/i })
    ).toBeEnabled();
    expect(String(fetchMock.mock.calls[0][0])).toMatch(
      /\/api\/v1\/materials\/abc-123$/
    );
  });

  it('muestra un estado controlado ante un 404', async () => {
    mockApi(() => json({ statusCode: 404 }, 404));
    renderRoute('/material/no-existe');

    expect(
      await screen.findByText('No encontramos este material')
    ).toBeInTheDocument();
    expect(
      screen.getByRole('link', { name: /volver al catálogo/i })
    ).toHaveAttribute('href', '/catalog');
  });

  it('muestra "no disponible" ante un error 500', async () => {
    mockApi(() => json({}, 500));
    renderRoute('/material/abc-123');
    expect(
      await screen.findByText('Este material no está disponible por ahora')
    ).toBeInTheDocument();
  });
});
