// @vitest-environment jsdom

import { render, screen, within } from '@testing-library/react';
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

describe('HomePage - Issue #256: Reemplazo de materiales mock por reales y revisión orientada al estudiante', () => {
  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal('fetch', fetchMock);
    vi.stubEnv('VITE_API_URL', 'https://gateway.test/api/v1');
  });

  it('consume materiales reales y los refleja en tarjetas básicas con textos orientados al estudiante', async () => {
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

    // Textos orientados al estudiante (sin nombres de servicios de backend internos)
    expect(
      screen.getByText('Materiales compartidos por la comunidad.')
    ).toBeInTheDocument();
    expect(screen.queryByText(/material service/i)).not.toBeInTheDocument();

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

  it('soporta de forma robusta un backend vacío sin romper la UI y con textos amigables', async () => {
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

    // El estado vacío debe indicar "publicados" y no asumir que es el primer aporte realizado
    const emptyState = await screen.findByTestId('empty-materials-state');
    expect(
      within(emptyState).getByText('Aún no hay materiales publicados')
    ).toBeInTheDocument();
    expect(
      within(emptyState).getByText(
        'Comparte guías, apuntes o evaluaciones con tus compañeros.'
      )
    ).toBeInTheDocument();
    expect(
      screen.queryByText('Aún no hay materiales registrados')
    ).not.toBeInTheDocument();
    expect(screen.queryByText(/sé el primero/i)).not.toBeInTheDocument();
    expect(
      within(emptyState).getByRole('link', { name: /subir material/i })
    ).toHaveAttribute('href', '/materials/upload');
  });

  it('mantiene la sección de mejor calificados con aviso para el estudiante y sin mención técnica a Quality Service', async () => {
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
      screen.getByText('Las calificaciones estarán disponibles próximamente')
    ).toBeInTheDocument();
    expect(
      screen.getByText(
        /Las calificaciones, reseñas y el posicionamiento por reputación estarán disponibles próximamente/i
      )
    ).toBeInTheDocument();
    expect(screen.queryByText(/quality service/i)).not.toBeInTheDocument();
  });

  it('conserva estrictamente el orden recibido del backend y comprueba explícitamente que no se muestran calificaciones inventadas', async () => {
    const backendItems = [
      {
        id: 'mat-order-1',
        title: 'Material Alfa - Álgebra',
        subjectId: 'sub-1',
        professorId: 'prof-1',
        academicYear: 2024,
        materialType: 'DOCUMENT',
      },
      {
        id: 'mat-order-2',
        title: 'Material Beta - Base de Datos',
        subjectId: 'sub-2',
        professorId: null,
        academicYear: 2026,
        materialType: 'EXAM',
      },
      {
        id: 'mat-order-3',
        title: 'Material Gamma - Cálculo',
        subjectId: null,
        professorId: 'prof-1',
        academicYear: 2023,
        materialType: 'SUMMARY',
      },
      {
        id: 'mat-order-4',
        title: 'Material Delta - Redes',
        subjectId: null,
        professorId: null,
        academicYear: 2025,
        materialType: 'CLASS_NOTES',
      },
    ];

    fetchMock.mockImplementation((input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes('/materials')) {
        return Promise.resolve(
          json({
            items: backendItems,
            page: 1,
            pageSize: 4,
            total: 4,
            totalPages: 1,
          })
        );
      }
      if (url.includes('/catalog/subjects')) {
        return Promise.resolve(
          json([
            { id: 'sub-1', name: 'Álgebra Lineal' },
            { id: 'sub-2', name: 'Bases de Datos' },
          ])
        );
      }
      if (url.includes('/catalog/professors')) {
        return Promise.resolve(
          json([{ id: 'prof-1', name: 'Prof. Ana María' }])
        );
      }
      return Promise.resolve(json([]));
    });

    renderHomePage();

    // Esperar a que carguen los materiales
    await screen.findByText('Material Alfa - Álgebra');

    // 1. Validar que las tarjetas conservan exactamente el orden recibido del backend
    const grid = screen.getByTestId('recent-materials-grid');
    const articles = within(grid).getAllByRole('article');
    expect(articles).toHaveLength(4);

    const renderedTitles = within(grid)
      .getAllByRole('heading', { level: 3 })
      .map((heading) => heading.textContent);

    expect(renderedTitles).toEqual([
      'Material Alfa - Álgebra',
      'Material Beta - Base de Datos',
      'Material Gamma - Cálculo',
      'Material Delta - Redes',
    ]);

    const renderedLinks = within(grid)
      .getAllByRole('link')
      .map((link) => link.getAttribute('href'));

    expect(renderedLinks).toEqual([
      '/material/mat-order-1',
      '/material/mat-order-2',
      '/material/mat-order-3',
      '/material/mat-order-4',
    ]);

    // 2. Comprobar explícitamente que no se muestran calificaciones inventadas en el frontend
    articles.forEach((card) => {
      expect(card.textContent).not.toMatch(
        /★|⭐|rating|calificaci[óo]n|puntuaci[óo]n|\/5|\/10/i
      );
    });

    // En toda la vista no se exhiben estrellas, puntuaciones artificiales ni componentes de rating
    expect(screen.queryByText(/★/)).not.toBeInTheDocument();
    expect(screen.queryByText(/⭐/)).not.toBeInTheDocument();
    expect(screen.queryByTestId('rating')).not.toBeInTheDocument();
    expect(screen.queryByTestId('stars')).not.toBeInTheDocument();
  });

  it('maneja errores del backend con un mensaje de alerta sin romper la página', async () => {
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
