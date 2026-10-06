import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import type { MaterialListItem } from '../../../domain/material/materialListItem';
import { MaterialCard } from './MaterialCard';

function buildMaterial(
  overrides: Partial<MaterialListItem> = {}
): MaterialListItem {
  return {
    id: 'mat-1',
    title: 'Certamen 1 - Algoritmos y Árboles',
    subjectName: 'Estructuras de Datos',
    professorName: 'Carlos Ramírez',
    year: 2026,
    type: 'EXAM',
    ...overrides,
  };
}

function renderCard(material: MaterialListItem) {
  return render(
    <MemoryRouter>
      <MaterialCard material={material} />
    </MemoryRouter>
  );
}

describe('MaterialCard', () => {
  it('muestra título, asignatura, profesor, año y tipo', () => {
    renderCard(buildMaterial());

    expect(
      screen.getByText('Certamen 1 - Algoritmos y Árboles')
    ).toBeInTheDocument();
    expect(screen.getByText('Estructuras de Datos')).toBeInTheDocument();
    expect(screen.getByText('Carlos Ramírez')).toBeInTheDocument();
    expect(screen.getByText('2026')).toBeInTheDocument();
    expect(screen.getByText('Prueba')).toBeInTheDocument();
  });

  it('enlaza al detalle del material', () => {
    renderCard(buildMaterial({ id: 'abc-123' }));

    expect(screen.getByRole('link')).toHaveAttribute(
      'href',
      '/material/abc-123'
    );
  });

  it('muestra el tipo original si no tiene etiqueta conocida', () => {
    renderCard(buildMaterial({ type: 'Laboratorio' }));

    expect(screen.getByText('Laboratorio')).toBeInTheDocument();
  });

  it('funciona sin datos opcionales ni información de Quality Service', () => {
    renderCard(
      buildMaterial({
        subjectName: null,
        professorName: null,
        year: null,
        type: null,
      })
    );

    expect(screen.getByText('Asignatura por definir')).toBeInTheDocument();
    expect(screen.getByText('Profesor por definir')).toBeInTheDocument();
    expect(screen.getByText('Año por definir')).toBeInTheDocument();
    expect(screen.getByText('Por definir')).toBeInTheDocument();
  });
});
