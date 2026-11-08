import { describe, expect, it } from 'vitest';
import { buildSearchParams, parseSearchUrl } from './searchUrlState';

describe('searchUrlState', () => {
  it('lee filtros, año y tipo de la URL', () => {
    const state = parseSearchUrl(
      new URLSearchParams(
        'q=algebra&universityId=u1&careerId=c1&subjectId=s1&professorId=p1&year=2026&type=EXAM'
      )
    );
    expect(state.filters).toEqual({
      universityId: 'u1',
      careerId: 'c1',
      subjectId: 's1',
      professorId: 'p1',
      year: 2026,
      type: 'EXAM',
    });
  });

  it('descarta niveles huérfanos de la cascada para evitar un 400', () => {
    const { filters } = parseSearchUrl(
      new URLSearchParams('careerId=c1&subjectId=s1&professorId=p1')
    );
    expect(filters.universityId).toBeUndefined();
    expect(filters.careerId).toBeUndefined();
    expect(filters.subjectId).toBeUndefined();
    expect(filters.professorId).toBeUndefined();
  });

  it.each(['1899', '2100', 'abc', '20.5', ''])(
    'ignora el año inválido "%s"',
    (year) => {
      const { filters } = parseSearchUrl(new URLSearchParams({ year }));
      expect(filters.year).toBeUndefined();
    }
  );

  it('serializa solo los filtros presentes', () => {
    const params = buildSearchParams({
      q: '',
      sort: 'recent',
      page: 1,
      filters: { universityId: 'u1', year: 2026 },
    });
    expect(params.toString()).toBe('sort=recent&universityId=u1&year=2026');
  });
});
