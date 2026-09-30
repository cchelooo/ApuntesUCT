import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { CatalogPage } from './CatalogPage';

// Helper para crear un cliente de React Query limpio
const createTestQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        retry: false, // Desactivar reintentos para que los tests fallen rápido
      },
    },
  });

describe('Pruebas de Integración - CatalogPage', () => {
  let queryClient: QueryClient;

  beforeEach(() => {
    queryClient = createTestQueryClient();
    vi.stubGlobal('fetch', vi.fn());
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    queryClient.clear();
  });

  it('1. Debe mostrar el estado de carga (Spinner o Skeleton) inicial', () => {
    // Simulamos una promesa que no se resuelve de inmediato
    vi.mocked(fetch).mockImplementation(() => new Promise(() => {}));

    render(
      <QueryClientProvider client={queryClient}>
        <CatalogPage />
      </QueryClientProvider>
    );

    // Verificamos que se muestra el texto de carga o los elementos con animación (skeleton)
    expect(screen.getByText(/cargando asignaturas/i)).toBeInTheDocument();
  });

  it('2. Debe mostrar alerta de error cuando la API falla', async () => {
    // Simulamos un error 500
    vi.mocked(fetch).mockResolvedValueOnce({
      ok: false,
      status: 500,
      json: async () => ({ message: 'Error interno del servidor' }),
    } as Response);

    render(
      <QueryClientProvider client={queryClient}>
        <CatalogPage />
      </QueryClientProvider>
    );

    // Esperamos a que la alerta de error sea renderizada
    await waitFor(() => {
      expect(
        screen.getByText(/no se pudo cargar el catálogo/i)
      ).toBeInTheDocument();
    });

    expect(
      screen.getByText(/intenta recargar la página en unos minutos/i)
    ).toBeInTheDocument();
  });

  it('3. Debe renderizar los datos del backend correctamente (contrato válido)', async () => {
    // Simulamos una respuesta exitosa con la estructura del contrato esperado
    const mockData = [
      {
        id: 'uuid-1',
        name: 'Ingeniería de Software',
        code: 'INF-301',
        semester: 5,
        active: true,
        careerId: 'c-1',
        createdAt: '2026-01-01',
        updatedAt: '2026-01-01',
        career: {
          id: 'c-1',
          name: 'Ingeniería Civil',
          code: 'IC',
          active: true,
          university: {
            id: 'u-1',
            name: 'UCT',
            code: 'UCT',
            active: true,
          },
        },
        professors: [],
      },
    ];

    vi.mocked(fetch).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => mockData,
    } as Response);

    render(
      <QueryClientProvider client={queryClient}>
        <CatalogPage />
      </QueryClientProvider>
    );

    // Esperamos a que los datos se rendericen
    await waitFor(() => {
      expect(screen.getByText('Ingeniería de Software')).toBeInTheDocument();
    });
  });
});
