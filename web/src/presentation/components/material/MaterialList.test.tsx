import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import type { MaterialListItem } from '../../../domain/material/materialListItem';
import { MaterialList } from './MaterialList';

const materials: MaterialListItem[] = [
  {
    id: 'm1',
    title: 'Resumen unidad 1',
    subjectName: 'Cálculo I',
    professorName: 'Marcela Huenchul',
    year: 2025,
    type: 'SUMMARY',
  },
  {
    id: 'm2',
    title: 'Guía de ejercicios',
    subjectName: 'Álgebra',
    professorName: null,
    year: 2026,
    type: 'GUIDE',
  },
];

function renderList(props: Parameters<typeof MaterialList>[0]) {
  return render(
    <MemoryRouter>
      <MaterialList {...props} />
    </MemoryRouter>
  );
}

describe('MaterialList', () => {
  it('renderiza una tarjeta por material', () => {
    renderList({ materials });

    expect(screen.getAllByRole('listitem')).toHaveLength(2);
    expect(screen.getByText('Resumen unidad 1')).toBeInTheDocument();
    expect(screen.getByText('Guía de ejercicios')).toBeInTheDocument();
  });

  it('muestra esqueletos y un aviso accesible mientras carga', () => {
    renderList({ materials: [], isLoading: true, skeletonCount: 3 });

    expect(screen.getAllByTestId('material-card-skeleton')).toHaveLength(3);
    expect(screen.getByRole('status')).toHaveTextContent('Cargando materiales');
    expect(screen.queryByText('Aún no hay materiales')).not.toBeInTheDocument();
  });

  it('muestra el estado vacío cuando no hay materiales', () => {
    renderList({ materials: [] });

    expect(screen.getByText('Aún no hay materiales')).toBeInTheDocument();
    expect(screen.queryByRole('listitem')).not.toBeInTheDocument();
  });

  it('permite personalizar el mensaje vacío', () => {
    renderList({
      materials: [],
      emptyTitle: 'Sin resultados',
      emptyDescription: 'Prueba con otra asignatura.',
    });

    expect(screen.getByText('Sin resultados')).toBeInTheDocument();
    expect(screen.getByText('Prueba con otra asignatura.')).toBeInTheDocument();
  });
});
