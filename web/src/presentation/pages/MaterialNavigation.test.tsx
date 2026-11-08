import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { LibraryPage } from './LibraryPage';
import { MaterialDetailRoute } from './MaterialDetailRoute';
import { SearchPage } from './SearchPage';

const GATEWAY = 'https://gateway.test/api/v1';
const MATERIAL_ID = '9f1c2a34-5b6d-4e7f-8a90-b1c2d3e4f5a6';
const SUBJECT_ID = '44444444-4444-4444-8444-444444444444';
const TITLE = 'Certamen 1 - Algoritmos';

const fetchMock = vi.fn();
const originalCreateObjectURL = URL.createObjectURL;
const originalRevokeObjectURL = URL.revokeObjectURL;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

const listItem = {
  id: MATERIAL_ID,
  title: TITLE,
  academicYear: 2026,
  materialType: 'EXAM',
  subjectId: SUBJECT_ID,
  professorId: null,
};

function detailBody() {
  return {
    ...listItem,
    description: null,
    uploaderId: '33333333-3333-4333-8333-333333333333',
    academicOfferingId: null,
    universityId: null,
    careerId: null,
    materialTypeId: '66666666-6666-4666-8666-666666666666',
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
  };
}

interface Handlers {
  detail?: () => Response;
  download?: () => Response | Promise<Response>;
}

function mockApi({ detail, download }: Handlers = {}) {
  fetchMock.mockImplementation((input: RequestInfo | URL) => {
    const { pathname } = new URL(String(input));
    if (/\/materials\/[^/]+\/download$/.test(pathname)) {
      return Promise.resolve(
        download?.() ??
          new Response('%PDF-1.7', {
            status: 200,
            headers: {
              'Content-Type': 'application/pdf',
              'Content-Disposition': 'attachment; filename="certamen.pdf"',
            },
          })
      );
    }
    if (/\/materials\/[^/]+$/.test(pathname)) {
      return Promise.resolve(detail?.() ?? json(detailBody()));
    }
    if (pathname.endsWith('/materials')) {
      return Promise.resolve(
        json({ items: [listItem], page: 1, pageSize: 20, total: 1 })
      );
    }
    if (pathname.endsWith('/search')) {
      return Promise.resolve(
        json({ results: [listItem], page: 1, pageSize: 20, total: 1 })
      );
    }
    if (pathname.endsWith('/catalog/subjects')) {
      return Promise.resolve(
        json([{ id: SUBJECT_ID, name: 'Estructuras de Datos' }])
      );
    }
    return Promise.resolve(json([]));
  });
}

function callsTo(pattern: RegExp): string[] {
  return fetchMock.mock.calls
    .map((call) => String(call[0]))
    .filter((url) => pattern.test(new URL(url).pathname));
}

function renderAt(path: string) {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter initialEntries={[path]}>
        <Routes>
          <Route path="/library" element={<LibraryPage />} />
          <Route path="/search" element={<SearchPage />} />
          <Route
            path="/material/:materialId"
            element={<MaterialDetailRoute />}
          />
          <Route path="/catalog" element={<p>Página Catálogo</p>} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>
  );
}

async function openCard() {
  await userEvent.click(
    await screen.findByRole('link', { name: /Certamen 1/ })
  );
}

describe('Navegación Material → Detalle → Descarga', () => {
  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal('fetch', fetchMock);
    vi.stubEnv('VITE_API_URL', GATEWAY);
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

  describe.each([
    ['Biblioteca', '/library'],
    ['Búsqueda', '/search?q=certamen'],
  ])('desde %s', (_label, path) => {
    it('la tarjeta enlaza al ID real y el detalle carga con ese ID', async () => {
      mockApi();
      renderAt(path);

      const card = await screen.findByRole('link', { name: /Certamen 1/ });
      expect(card).toHaveAttribute('href', `/material/${MATERIAL_ID}`);

      await userEvent.click(card);

      expect(
        await screen.findByRole('heading', { name: TITLE, level: 1 })
      ).toBeInTheDocument();
      expect(screen.getByTestId('material-id')).toHaveTextContent(MATERIAL_ID);
      expect(screen.getByText('PDF')).toBeInTheDocument();
      expect(callsTo(/\/materials\/[^/]+$/)).toEqual([
        `${GATEWAY}/materials/${MATERIAL_ID}`,
      ]);
    });

    it('la descarga se solicita al Gateway con el mismo ID y entrega el archivo', async () => {
      mockApi();
      renderAt(path);
      await openCard();

      const button = await screen.findByRole('button', {
        name: /descargar material/i,
      });
      await waitFor(() => expect(button).toBeEnabled());
      expect(callsTo(/\/download$/)).toHaveLength(0);

      await userEvent.click(button);

      await waitFor(() =>
        expect(callsTo(/\/download$/)).toEqual([
          `${GATEWAY}/materials/${MATERIAL_ID}/download`,
        ])
      );
      await waitFor(() => expect(URL.createObjectURL).toHaveBeenCalledTimes(1));
      expect(HTMLAnchorElement.prototype.click).toHaveBeenCalledTimes(1);
      expect(screen.queryByRole('alert')).not.toBeInTheDocument();
    });
  });

  it('todas las llamadas del recorrido pasan por el Gateway', async () => {
    mockApi();
    renderAt('/library');
    await openCard();
    await userEvent.click(
      await screen.findByRole('button', { name: /descargar material/i })
    );
    await waitFor(() => expect(callsTo(/\/download$/)).toHaveLength(1));

    expect(fetchMock.mock.calls.length).toBeGreaterThan(0);
    expect(
      fetchMock.mock.calls.every(([url]) => String(url).startsWith(GATEWAY))
    ).toBe(true);
  });

  describe('errores controlados', () => {
    it('un 404 en el detalle muestra el estado "no encontrado" con salida al catálogo', async () => {
      mockApi({
        detail: () =>
          json({ statusCode: 404, message: 'Material no encontrado.' }, 404),
      });
      renderAt('/library');
      await openCard();

      expect(
        await screen.findByText('No encontramos este material')
      ).toBeInTheDocument();
      expect(
        screen.queryByRole('button', { name: /descargar material/i })
      ).not.toBeInTheDocument();
      expect(callsTo(/\/materials\/[^/]+$/)).toHaveLength(1);

      await userEvent.click(
        screen.getByRole('link', { name: /volver al catálogo/i })
      );
      expect(await screen.findByText('Página Catálogo')).toBeInTheDocument();
    });

    it.each([
      [
        'HTTP 404',
        () => json({ message: 'Archivo no disponible.' }, 404),
        'El material, la versión o el archivo no están disponibles.',
      ],
      [
        'HTTP 503',
        () => json({ message: 'Almacenamiento no disponible.' }, 503),
        'Error temporal en el servidor. Por favor, intenta más tarde.',
      ],
    ])(
      'un error de descarga (%s) muestra alerta y permite reintentar',
      async (_label, failure, message) => {
        let attempts = 0;
        mockApi({
          download: () => {
            attempts += 1;
            return attempts === 1
              ? failure()
              : new Response('%PDF-1.7', {
                  status: 200,
                  headers: { 'Content-Type': 'application/pdf' },
                });
          },
        });
        renderAt('/library');
        await openCard();

        await userEvent.click(
          await screen.findByRole('button', { name: /descargar material/i })
        );

        expect(await screen.findByRole('alert')).toHaveTextContent(message);
        expect(URL.createObjectURL).not.toHaveBeenCalled();
        expect(
          screen.getByRole('heading', { name: TITLE, level: 1 })
        ).toBeInTheDocument();

        await userEvent.click(
          screen.getByRole('button', { name: /reintentar descarga/i })
        );

        await waitFor(() =>
          expect(URL.createObjectURL).toHaveBeenCalledTimes(1)
        );
        expect(screen.queryByRole('alert')).not.toBeInTheDocument();
        expect(callsTo(/\/download$/)).toHaveLength(2);
      }
    );

    it('un fallo de red en la descarga muestra el mensaje de conexión', async () => {
      mockApi();
      const base = fetchMock.getMockImplementation()!;
      fetchMock.mockImplementation((input: RequestInfo | URL) =>
        /\/download$/.test(new URL(String(input)).pathname)
          ? Promise.reject(new TypeError('Failed to fetch'))
          : base(input)
      );
      renderAt('/library');
      await openCard();

      await userEvent.click(
        await screen.findByRole('button', { name: /descargar material/i })
      );

      expect(await screen.findByRole('alert')).toHaveTextContent(
        'Error de conexión. Por favor, verifica tu conexión a internet e intenta nuevamente.'
      );
    });
  });
});
