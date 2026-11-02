import { afterEach, describe, expect, it, vi } from 'vitest';
import { fetchSearch } from './searchApi';

const GATEWAY = 'https://gateway.test/api/v1';

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe('searchApi', () => {
  it('envía la búsqueda al Gateway con los parámetros solicitados', async () => {
    vi.stubEnv('VITE_API_URL', GATEWAY);
    const fetchMock = vi
      .fn()
      .mockResolvedValue(
        Response.json({ results: [], page: 2, pageSize: 10, total: 0 })
      );
    vi.stubGlobal('fetch', fetchMock);
    const signal = new AbortController().signal;

    await fetchSearch(
      { q: 'álgebra', sort: 'year_desc', page: 2, pageSize: 10 },
      signal
    );

    expect(fetchMock).toHaveBeenCalledWith(
      `${GATEWAY}/search?q=%C3%A1lgebra&sortBy=year&order=desc&page=2&pageSize=10`,
      { signal }
    );
  });

  it('no consulta un origen alternativo cuando VITE_API_URL está vacía', async () => {
    vi.stubEnv('VITE_API_URL', '');
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    await expect(fetchSearch({ q: 'álgebra' })).rejects.toThrow('VITE_API_URL');
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
