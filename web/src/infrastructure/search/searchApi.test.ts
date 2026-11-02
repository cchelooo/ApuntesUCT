import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { buildSearchQuery, fetchSearch } from './searchApi';

const GATEWAY = 'https://gateway.test/api/v1';

describe('searchApi', () => {
  beforeEach(() => {
    vi.stubEnv('VITE_API_URL', GATEWAY);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

  it('construye texto, filtros y paginación para la búsqueda', () => {
    const params = buildSearchQuery({
      q: '  cálculo  ',
      sort: 'year_desc',
      page: 3,
      pageSize: 12,
      filters: {
        universityId: 'u1',
        careerId: 'c1',
        subjectId: 's1',
        professorId: 'p1',
        year: 2026,
        type: 'EXAM',
      },
    });

    expect(params.toString()).toBe(
      'q=c%C3%A1lculo&universityId=u1&careerId=c1&subjectId=s1&professorId=p1&year=2026&type=EXAM&sortBy=year&order=desc&page=3&pageSize=12'
    );
  });

  it('consulta Search exclusivamente a través del Gateway', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          results: [{ id: 'm1', title: 'Guía', academicYear: 2026 }],
          page: 2,
          pageSize: 10,
          total: 11,
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    );
    vi.stubGlobal('fetch', fetchMock);

    await fetchSearch({ q: 'guía', page: 2, pageSize: 10 });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const requestedUrl = new URL(String(fetchMock.mock.calls[0][0]));
    expect(requestedUrl.origin + requestedUrl.pathname).toBe(`${GATEWAY}/search`);
    expect(requestedUrl.searchParams.get('q')).toBe('guía');
    expect(requestedUrl.searchParams.get('page')).toBe('2');
    expect(requestedUrl.pathname).not.toContain('material');
  });
});
