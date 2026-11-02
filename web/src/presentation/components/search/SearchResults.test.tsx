import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import type { SearchResultPage } from '../../../domain/search/search';
import { SearchResults } from './SearchResults';

const mockCatalogNames = {
  subjects: { 'sub-1': 'Cálculo Avanzado' },
  professors: { 'prof-1': 'Dr. Roberto Soto' },
};

function sampleSearchResultPage(
  overrides: Partial<SearchResultPage> = {}
): SearchResultPage {
  return {
    items: [
      {
        id: 'mat-1',
        title: 'Guía de Ecuaciones Diferenciales',
        subjectId: 'sub-1',
        subjectName: null,
        professorId: 'prof-1',
        professorName: null,
        year: 2026,
        type: 'GUIDE',
      },
      {
        id: 'mat-2',
        title: 'Certamen Recuperativo',
        subjectId: null,
        subjectName: null,
        professorId: null,
        professorName: null,
        year: 2025,
        type: 'EXAM',
      },
    ],
    page: 1,
    pageSize: 20,
    total: 2,
    totalPages: 1,
    ...overrides,
  };
}

function renderSearchResults(
  props: Partial<Parameters<typeof SearchResults>[0]> = {},
  catalogData = mockCatalogNames
) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  queryClient.setQueryData(['catalog', 'names'], catalogData);

  const defaultProps: Parameters<typeof SearchResults>[0] = {
    query: 'ecuaciones',
    data: undefined,
    isLoading: false,
    isFetching: false,
    isError: false,
    error: null,
    onRetry: vi.fn(),
    onPageChange: vi.fn(),
    ...props,
  };

  return {
    ...render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <SearchResults {...defaultProps} />
        </MemoryRouter>
      </QueryClientProvider>
    ),
    props: defaultProps,
  };
}

describe('SearchResults - Issue #257: Pruebas de estados de listado y búsqueda', () => {
  describe('Estado de carga (loading)', () => {
    it('muestra esqueletos de carga y texto accesible mientras isLoading es true', () => {
      renderSearchResults({
        isLoading: true,
        data: undefined,
      });

      expect(screen.getByRole('status')).toHaveTextContent(
        'Cargando materiales'
      );
      const skeletons = screen.getAllByTestId('material-card-skeleton');
      expect(skeletons.length).toBeGreaterThan(0);
      expect(screen.queryByText(/resultados para/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/sin resultados/i)).not.toBeInTheDocument();
    });

    it('indica el estado ocupado con aria-busy cuando isFetching es true', () => {
      const data = sampleSearchResultPage();
      const { container } = renderSearchResults({
        data,
        isLoading: false,
        isFetching: true,
      });

      const busyContainer = container.querySelector('[aria-busy="true"]');
      expect(busyContainer).toBeInTheDocument();
    });
  });

  describe('Manejo de errores (error)', () => {
    it('muestra una alerta con mensaje amigable y botón de reintento cuando falla sin datos previos', () => {
      renderSearchResults({
        isError: true,
        error: { status: 500 },
        data: undefined,
      });

      const alert = screen.getByRole('alert');
      expect(alert).toHaveTextContent(
        'Error temporal en el servidor. Por favor, intenta más tarde.'
      );
      expect(
        screen.getByRole('button', { name: 'Reintentar' })
      ).toBeInTheDocument();
      expect(screen.queryByRole('status')).not.toBeInTheDocument();
    });

    it('ejecuta el callback onRetry al pulsar el botón de reintentar', async () => {
      const onRetry = vi.fn();
      renderSearchResults({
        isError: true,
        error: { status: 502 },
        data: undefined,
        onRetry,
      });

      const retryButton = screen.getByRole('button', { name: 'Reintentar' });
      await userEvent.click(retryButton);

      expect(onRetry).toHaveBeenCalledTimes(1);
    });

    it('deshabilita el botón de reintento e informa reintentando cuando isFetching es true', () => {
      renderSearchResults({
        isError: true,
        error: { status: 500 },
        data: undefined,
        isFetching: true,
      });

      const retryButton = screen.getByRole('button', {
        name: 'Reintentando...',
      });
      expect(retryButton).toBeDisabled();
    });

    it('conserva los materiales previos y muestra la alerta si ocurre un error en segundo plano con datos existentes', () => {
      const data = sampleSearchResultPage();
      renderSearchResults({
        data,
        isError: true,
        error: { status: 503 },
        isLoading: false,
      });

      expect(screen.getByRole('alert')).toHaveTextContent(
        'Error temporal en el servidor. Por favor, intenta más tarde.'
      );
      expect(
        screen.getByText('Guía de Ecuaciones Diferenciales')
      ).toBeInTheDocument();
      expect(screen.getByText('Certamen Recuperativo')).toBeInTheDocument();
    });
  });

  describe('Cero resultados (empty / listado vacío)', () => {
    it('muestra el estado vacío específico con sugerencia cuando la búsqueda no tiene coincidencias', () => {
      const emptyPage: SearchResultPage = {
        items: [],
        page: 1,
        pageSize: 20,
        total: 0,
        totalPages: 0,
      };

      renderSearchResults({
        query: 'materia-inexistente',
        data: emptyPage,
        isLoading: false,
      });

      expect(
        screen.getByText('Sin resultados para “materia-inexistente”')
      ).toBeInTheDocument();
      expect(
        screen.getByText('Prueba con otras palabras o revisa la ortografía.')
      ).toBeInTheDocument();
      expect(
        screen.getByText('0 resultados para “materia-inexistente”')
      ).toBeInTheDocument();
      expect(screen.queryByRole('listitem')).not.toBeInTheDocument();
      expect(
        screen.queryByTestId('material-card-skeleton')
      ).not.toBeInTheDocument();
    });
  });

  describe('Materiales obtenidos correctamente (éxito con datos)', () => {
    it('renderiza la lista de materiales con resolución de catálogo, conteo y enlaces al detalle', () => {
      const data = sampleSearchResultPage();
      renderSearchResults({
        query: 'ecuaciones',
        data,
        isLoading: false,
      });

      expect(
        screen.getByText('2 resultados para “ecuaciones”')
      ).toBeInTheDocument();
      expect(
        screen.getByText('Guía de Ecuaciones Diferenciales')
      ).toBeInTheDocument();
      expect(screen.getByText('Cálculo Avanzado')).toBeInTheDocument();
      expect(screen.getByText('Dr. Roberto Soto')).toBeInTheDocument();
      expect(screen.getByText('Certamen Recuperativo')).toBeInTheDocument();

      const links = screen.getAllByRole('link');
      const detailLink = links.find((link) =>
        link.getAttribute('href')?.includes('/material/mat-1')
      );
      expect(detailLink).toBeDefined();
    });

    it('renderiza la paginación y permite navegar entre páginas de resultados', async () => {
      const onPageChange = vi.fn();
      const pagedData = sampleSearchResultPage({
        total: 40,
        page: 1,
        totalPages: 2,
        pageSize: 20,
      });

      renderSearchResults({
        query: 'ecuaciones',
        data: pagedData,
        onPageChange,
      });

      expect(screen.getByText(/Página 1 de 2/)).toBeInTheDocument();
      const nextButton = screen.getByRole('button', { name: 'Siguiente' });
      expect(nextButton).toBeEnabled();

      await userEvent.click(nextButton);
      expect(onPageChange).toHaveBeenCalledWith(2);
    });
  });
});
