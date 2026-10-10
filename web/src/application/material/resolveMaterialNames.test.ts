import { describe, expect, it } from 'vitest';
import type { MaterialListItem } from '../../domain/material/materialListItem';
import { resolveMaterialNames } from './resolveMaterialNames';

const names = {
  subjects: { 's-1': 'Estructuras de Datos' },
  professors: { 'p-1': 'Carlos Ramírez' },
};

function item(overrides: Partial<MaterialListItem> = {}): MaterialListItem {
  return {
    id: 'm-1',
    title: 'Guía',
    subjectName: null,
    professorName: null,
    year: 2026,
    type: 'GUIDE',
    subjectId: 's-1',
    professorId: 'p-1',
    ...overrides,
  };
}

describe('resolveMaterialNames', () => {
  it('resuelve asignatura y profesor por ID', () => {
    const [result] = resolveMaterialNames([item()], names);
    expect(result.subjectName).toBe('Estructuras de Datos');
    expect(result.professorName).toBe('Carlos Ramírez');
  });

  it('mantiene null cuando no hay profesor asociado', () => {
    const [result] = resolveMaterialNames([item({ professorId: null })], names);
    expect(result.professorName).toBeNull();
  });

  it('mantiene null si el catálogo no conoce el ID', () => {
    const [result] = resolveMaterialNames(
      [item({ subjectId: 'otro', professorId: 'otro' })],
      names
    );
    expect(result.subjectName).toBeNull();
    expect(result.professorName).toBeNull();
  });

  it('devuelve los ítems sin cambios mientras el catálogo no está disponible', () => {
    const items = [item()];
    expect(resolveMaterialNames(items, undefined)).toBe(items);
  });
});
