import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MaterialDetailRoute } from './MaterialDetailRoute';

const GATEWAY = 'https://gateway.test/api/v1';
const MATERIAL_ID = '11111111-1111-4111-8111-111111111111';
const fetchMock = vi.fn();
const originalCreateObjectURL = URL.createObjectURL;
const originalRevokeObjectURL = URL.revokeObjectURL;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function contract(overrides: Record<string, unknown> = {}) {
  return {
    id: MATERIAL_ID,
    title: 'Certamen 1',
    description: null,
    uploaderId: '33333333-3333-4333-8333-333333333333',
    academicOfferingId: null,
    universityId: null,
    careerId: null,
    subjectId: '44444444-4444-4444-8444-444444444444',
    professorId: null,
    materialTypeId: '66666666-6666-4666-8666-666666666666',
    materialType: 'EXAM',
    academicYear: 2026,
    status: 'PUBLISHED',
    verified: false,
    externalLink: null,
    createdAt: '2026-10-01T12:00:00.000Z',
    updatedAt: '2026-10-01T12:00:00.000Z',
    currentVersion: {
      id: '22222222-2222-4222-8222-222222222222',
      versionNumber: 1,
      originalFilename: 'certamen.pdf',
      mimeType: 'application/pdf',
      fileSize: '2048',
      createdAt: '2026-10-02T12:00:00.000Z',
    },
    ...overrides,
  };
}

function mockApi(detail: () => Response) {
  fetchMock.mockImplementation((input: RequestInfo | URL) => {
    const { pathname } = new URL(String(input));
    if (/\/materials\/[^/]+\/download$/.test(pathname)) {
      return Promise.resolve(
        new Response(new Blob(['%PDF-1.7']), {
          status: 200,
          headers: { 'Content-Type': 'application/pdf' },
        })
      );
    }
    if (/\/materials\/[^/]+$/.test(pathname)) return Promise.resolve(detail());
    return Promise.resolve(json([]));
  });
}

function callsTo(suffix: RegExp): string[] {
  return fetchMock.mock.calls
    .map((call) => String(call[0]))
    .filter((url) => suffix.test(new URL(url).pathname));
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
    vi.stubEnv('VITE_API_URL', `${GATEWAY}/`);
    URL.createObjectURL = vi.fn(() => 'blob:mock');
    URL.revokeObjectURL = vi.fn();
    vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(
      () => undefined
    );
  });
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
    URL.createObjectURL = originalCreateObjectURL;
    URL.revokeObjectURL = originalRevokeObjectURL;
  });

  it('consulta el detalle por el Gateway y muestra metadatos y versión', async () => {
    mockApi(() => json(contract()));
    renderRoute(`/material/${MATERIAL_ID}`);

    expect(await screen.findByText('Certamen 1')).toBeInTheDocument();
    expect(screen.getByText('PDF')).toBeInTheDocument();
    expect(screen.getByText('2.0 KB')).toBeInTheDocument();
    expect(callsTo(/\/materials\/[^/]+$/)).toEqual([
      `${GATEWAY}/materials/${MATERIAL_ID}`,
    ]);
  });

  it('al pulsar "Descargar material" solicita la URL del Gateway y entrega el archivo', async () => {
    mockApi(() => json(contract()));
    renderRoute(`/material/${MATERIAL_ID}`);

    const button = await screen.findByRole('button', {
      name: /descargar material/i,
    });
    expect(button).toBeEnabled();
    expect(callsTo(/\/download$/)).toHaveLength(0);

    await userEvent.click(button);

    await waitFor(() =>
      expect(callsTo(/\/download$/)).toEqual([
        `${GATEWAY}/materials/${MATERIAL_ID}/download`,
      ])
    );
    await waitFor(() => expect(URL.createObjectURL).toHaveBeenCalledTimes(1));
    expect(HTMLAnchorElement.prototype.click).toHaveBeenCalledTimes(1);
  });

  it('sin archivo (currentVersion null) la descarga queda deshabilitada', async () => {
    mockApi(() =>
      json(
        contract({
          currentVersion: null,
          materialType: 'LINK',
          externalLink: 'https://example.com/clase',
        })
      )
    );
    renderRoute(`/material/${MATERIAL_ID}`);

    expect(
      await screen.findByRole('button', { name: /descargar material/i })
    ).toBeDisabled();
  });

  it('un 404 real muestra el estado controlado, con salida al catálogo y sin reintentos', async () => {
    mockApi(() =>
      json({ statusCode: 404, message: 'Material no encontrado.' }, 404)
    );
    renderRoute(`/material/${MATERIAL_ID}`);

    expect(
      await screen.findByText('No encontramos este material')
    ).toBeInTheDocument();
    expect(
      screen.getByRole('link', { name: /volver al catálogo/i })
    ).toHaveAttribute('href', '/catalog');
    expect(
      screen.queryByRole('button', { name: /descargar material/i })
    ).not.toBeInTheDocument();
    expect(callsTo(/\/materials\/[^/]+$/)).toHaveLength(1);
  });

  it('un 500 agota su único reintento y muestra "no disponible"', async () => {
    mockApi(() => json({}, 500));
    renderRoute(`/material/${MATERIAL_ID}`);

    expect(
      await screen.findByText(
        'Este material no está disponible por ahora',
        undefined,
        { timeout: 4000 }
      )
    ).toBeInTheDocument();
    expect(callsTo(/\/materials\/[^/]+$/)).toHaveLength(2);
  }, 10000);
});
