// @vitest-environment jsdom

import { render, screen } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { HomePage } from './HomePage';

const fetchMock = vi.fn();

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function renderHomePage() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <HomePage />
      </MemoryRouter>
    </QueryClientProvider>
  );
}

describe('HomePage - Issue #256: Reemplazo de materiales mock por reales', () => {
  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal('fetch', fetchMock);
    vi.stubEnv('VITE_API_URL', 'https://gateway.test/api/v1');
  });

  it('consume materiales reales desde Material Service y los refleja en tarjetas básicas', async () => {
    fetchMock.mockImplementation((input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes('/materials')) {
        return Promise.resolve(
          json({
            items: [
              {
                id: 'mat-real-1',
                title: 'Guía de Ecuaciones Diferenciales',
                subjectId: 'sub-1',
                professorId: 'prof-1',
                academicYear: 2026,
                materialType: 'DOCUMENT',
              },
              {
                id: 'mat-real-2',
                title: 'Resumen Termodinámica',
                subjectId: null,
                professorId: null,
                academicYear: 2025,
                materialType: 'SUMMARY',
              },
            ],
            page: 1,
            pageSize: 4,
            total: 2,
            totalPages: 1,
          })
        );
      }
      if (url.includes('/catalog/subjects')) {
        return Promise.resolve(
          json([{ id: 'sub-1', name: 'Cálculo Avanzado' }])
        );
      }
      if (url.includes('/catalog/professors')) {
        return Promise.resolve(
          json([{ id: 'prof-1', name: 'Dr. Roberto Soto' }])
        );
      }
      return Promise.resolve(json([]));
    });

    renderHomePage();

    // Verificación de tarjetas básicas con datos reales del servicio
    expect(
      await screen.findByText('Guía de Ecuaciones Diferenciales')
    ).toBeInTheDocument();
    expect(screen.getByText('Resumen Termodinámica')).toBeInTheDocument();
    expect(await screen.findByText('Cálculo Avanzado')).toBeInTheDocument();
    expect(await screen.findByText('Dr. Roberto Soto')).toBeInTheDocument();
    expect(screen.getByText('2026')).toBeInTheDocument();
    expect(screen.getByText('2025')).toBeInTheDocument();

    // Enlaces correspondientes al detalle de cada material
    const links = screen.getAllByRole('link');
    const material1Link = links.find((link) =>
      link.getAttribute('href')?.includes('/material/mat-real-1')
    );
    expect(material1Link).toBeDefined();
  });

  it('soporta de forma robusta un backend vacío sin romper la UI', async () => {
    fetchMock.mockImplementation((input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes('/materials')) {
        return Promise.resolve(
          json({
            items: [],
            page: 1,
            pageSize: 4,
            total: 0,
            totalPages: 0,
          })
        );
      }
      return Promise.resolve(json([]));
    });

    renderHomePage();

    // El estado vacío debe renderizarse de forma amigable con su rol accesible
    expect(
      await screen.findByText('Aún no hay materiales registrados')
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        'Sé el primero en compartir guías, apuntes o evaluaciones con tus compañeros.'
      )
    ).toBeInTheDocument();
    expect(
      screen.getByRole('link', { name: /subir primer material/i })
    ).toHaveAttribute('href', '/materials/upload');
  });

  it('mantiene la sección de mejor calificados preparada para Quality Service sin rating inventado', async () => {
    fetchMock.mockImplementation(() =>
      Promise.resolve(
        json({
          items: [],
          page: 1,
          pageSize: 4,
          total: 0,
          totalPages: 0,
        })
      )
    );

    renderHomePage();

    expect(screen.getByText('Mejores calificados')).toBeInTheDocument();
    expect(
      screen.getByTestId('quality-service-placeholder')
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        /Las calificaciones, reseñas y el posicionamiento por reputación se integrarán con Quality Service/i
      )
    ).toBeInTheDocument();
  });

  it('maneja errores de Material Service con un mensaje de alerta sin romper la página', async () => {
    fetchMock.mockImplementation((input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes('/materials')) {
        return Promise.resolve(json({ message: 'Internal Server Error' }, 500));
      }
      return Promise.resolve(json([]));
    });

    renderHomePage();

    expect(
      await screen.findByText(
        /No fue posible cargar los materiales recientes en este momento/i
      )
    ).toBeInTheDocument();
  });
});
