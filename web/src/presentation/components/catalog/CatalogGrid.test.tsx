import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import type { Subject } from '../../../domain/catalog/subject';
import { CatalogGrid } from './CatalogGrid';

function buildSubject(overrides: Partial<Subject> = {}): Subject {
  return {
    id: '1',
    code: 'ICI-201',
    name: 'Estructura de Datos',
    careerName: 'Ingeniería Civil en Informática',
    semester: 3,
    professorName: 'Carlos Ramírez',
    notesCount: 5,
    ...overrides,
  };
}

describe('CatalogGrid — estado "Sin resultados"', () => {
  it('muestra el mensaje de "Sin resultados" cuando no hay asignaturas para la búsqueda', () => {
    render(<CatalogGrid subjects={[]} query="algoritmos" />);

    expect(screen.getByText(/no hay asignaturas para/i)).toBeInTheDocument();
    expect(screen.getByText(/algoritmos/i)).toBeInTheDocument();
    expect(
      screen.getByText(
        /prueba buscando por otro nombre o por el código de la asignatura/i
      )
    ).toBeInTheDocument();
  });

  it('muestra el mensaje de "Sin resultados" también cuando la búsqueda está vacía y no hay asignaturas', () => {
    render(<CatalogGrid subjects={[]} query="" />);

    expect(screen.getByText(/no hay asignaturas para/i)).toBeInTheDocument();
  });

  it('no muestra el mensaje de "Sin resultados" cuando existen asignaturas', () => {
    render(<CatalogGrid subjects={[buildSubject()]} query="" />);

    expect(
      screen.queryByText(/no hay asignaturas para/i)
    ).not.toBeInTheDocument();
    expect(screen.getByText('Estructura de Datos')).toBeInTheDocument();
  });
});
