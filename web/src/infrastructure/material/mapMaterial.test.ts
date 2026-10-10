import { describe, expect, it } from 'vitest';
import { mapRawMaterial, mapRawMaterialPage } from './mapMaterial';

describe('mapMaterial (contrato real del backend)', () => {
  it('mapea academicYear y materialType a year y type', () => {
    expect(
      mapRawMaterial({
        id: 'm-1',
        title: 'Certamen 1',
        academicYear: 2026,
        materialType: 'EXAM',
        subjectId: 's-1',
        professorId: 'p-1',
      })
    ).toEqual({
      id: 'm-1',
      title: 'Certamen 1',
      year: 2026,
      type: 'EXAM',
      subjectName: null,
      professorName: null,
      subjectId: 's-1',
      professorId: 'p-1',
    });
  });

  it('ignora los campos year/type que el backend no entrega', () => {
    const item = mapRawMaterial({
      id: 'm-2',
      year: 2020,
      type: 'GUIDE',
    } as never);
    expect(item.year).toBeNull();
    expect(item.type).toBeNull();
  });

  it('permite materiales sin profesor', () => {
    const item = mapRawMaterial({ id: 'm-3', professorId: null });
    expect(item.professorId).toBeNull();
  });

  it('calcula totalPages a partir de total y pageSize', () => {
    const page = mapRawMaterialPage({
      items: [{ id: 'a' }],
      page: 1,
      pageSize: 20,
      total: 41,
    });
    expect(page.totalPages).toBe(3);
  });
});
