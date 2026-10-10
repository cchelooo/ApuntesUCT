import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MaterialListSection } from './MaterialListSection';

const SUBJECT_ID = '11111111-1111-4111-8111-111111111111';
const PROFESSOR_ID = '22222222-2222-4222-8222-222222222222';

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function material(overrides: Record<string, unknown> = {}) {
  return {
    id: 'real-uuid-1',
    title: 'Certamen 1 - Algoritmos',
    academicYear: 2026,
    materialType: 'EXAM',
    subjectId: SUBJECT_ID,
    professorId: PROFESSOR_ID,
    ...overrides,
  };
}

function page(items: unknown[], extra: Record<string, unknown> = {}) {
  return { items, page: 1, pageSize: 2, total: items.length, ...extra };
}

interface Handlers {
  materials: (url: URL) => Response;
  subjects?: () => Response;
  professors?: () => Response;
}

const fetchMock = vi.fn();

function mockApi({ materials, subjects, professors }: Handlers) {
  fetchMock.mockImplementation((input: RequestInfo | URL) => {
    const url = new URL(String(input));
    if (url.pathname.endsWith('/materials')) {
      return Promise.resolve(materials(url));
    }
    if (url.pathname.endsWith('/catalog/subjects')) {
      return Promise.resolve(
        subjects?.() ?? json([{ id: SUBJECT_ID, name: 'Estructuras de Datos' }])
      );
    }
    if (url.pathname.endsWith('/catalog/professors')) {
      return Promise.resolve(
        professors?.() ?? json([{ id: PROFESSOR_ID, name: 'Carlos Ramírez' }])
      );
    }
    return Promise.resolve(json({}, 404));
  });
}

function materialCalls(): string[] {
  return fetchMock.mock.calls
    .map((call) => String(call[0]))
    .filter((url) => url.includes('/materials?'));
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
  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal('fetch', fetchMock);
  });
  afterEach(() => vi.unstubAllGlobals());

  it('muestra carga y luego año, tipo, asignatura y profesor del contrato real', async () => {
    mockApi({ materials: () => json(page([material()])) });
    renderSection();

    expect(screen.getByRole('status')).toHaveTextContent('Cargando materiales');

    expect(
      await screen.findByText('Certamen 1 - Algoritmos')
    ).toBeInTheDocument();
    expect(screen.getByText('2026')).toBeInTheDocument();
    expect(screen.getByText('Prueba')).toBeInTheDocument();
    expect(await screen.findByText('Estructuras de Datos')).toBeInTheDocument();
    expect(await screen.findByText('Carlos Ramírez')).toBeInTheDocument();

    expect(screen.queryByText('Año por definir')).not.toBeInTheDocument();
    expect(
      screen.queryByText('Asignatura por definir')
    ).not.toBeInTheDocument();
    expect(screen.queryByText('Profesor por definir')).not.toBeInTheDocument();
    expect(screen.getByRole('link')).toHaveAttribute(
      'href',
      '/material/real-uuid-1'
    );
    expect(materialCalls()[0]).toContain('/materials?page=1&pageSize=2');
  });

  it('mantiene el texto alternativo cuando el material no tiene profesor', async () => {
    mockApi({
      materials: () => json(page([material({ professorId: null })])),
    });
    renderSection();

    expect(await screen.findByText('Estructuras de Datos')).toBeInTheDocument();
    expect(screen.getByText('Profesor por definir')).toBeInTheDocument();
    expect(screen.getByText('2026')).toBeInTheDocument();
  });

  it('muestra el listado con textos alternativos si falla el catálogo', async () => {
    mockApi({
      materials: () => json(page([material()])),
      subjects: () => json({}, 500),
      professors: () => json({}, 500),
    });
    renderSection();

    expect(
      await screen.findByText('Certamen 1 - Algoritmos')
    ).toBeInTheDocument();
    await waitFor(() =>
      expect(
        fetchMock.mock.calls.filter((call) =>
          String(call[0]).includes('/catalog/')
        )
      ).toHaveLength(2)
    );
    expect(screen.getByText('2026')).toBeInTheDocument();
    expect(screen.getByText('Prueba')).toBeInTheDocument();
    expect(screen.getByText('Asignatura por definir')).toBeInTheDocument();
    expect(screen.getByText('Profesor por definir')).toBeInTheDocument();
  });

  it('muestra la lista vacía', async () => {
    mockApi({ materials: () => json(page([])) });
    renderSection();
    expect(
      await screen.findByText('Aún no hay materiales')
    ).toBeInTheDocument();
  });

  it('muestra el error y permite reintentar', async () => {
    let attempts = 0;
    mockApi({
      materials: () => {
        attempts += 1;
        return attempts === 1
          ? json({}, 500)
          : json(page([material({ title: 'Resumen' })]));
      },
    });
    renderSection();

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Error temporal en el servidor'
    );
    await userEvent.click(screen.getByRole('button', { name: 'Reintentar' }));
    expect(await screen.findByText('Resumen')).toBeInTheDocument();
  });

  it('pagina con page/pageSize del backend', async () => {
    mockApi({
      materials: (url) =>
        url.searchParams.get('page') === '2'
          ? json(
              page([material({ id: 'p3', title: 'Página dos' })], {
                page: 2,
                total: 3,
              })
            )
          : json(
              page([material({ id: 'p1', title: 'Página uno' })], { total: 3 })
            ),
    });
    renderSection();

    await screen.findByText('Página uno');
    expect(screen.getByText(/Página 1 de 2/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Anterior' })).toBeDisabled();

    await userEvent.click(screen.getByRole('button', { name: 'Siguiente' }));
    expect(await screen.findByText('Página dos')).toBeInTheDocument();
    expect(materialCalls()[1]).toContain('page=2&pageSize=2');
    expect(screen.getByRole('button', { name: 'Siguiente' })).toBeDisabled();
  });
});
