import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  fetchCareers,
  fetchCatalogSubjects,
  fetchProfessorsBySubject,
  fetchSubjectsByCareer,
  fetchUniversities,
} from './catalogApi';
import {
  fetchCatalogProfessorNames,
  fetchCatalogSubjectNames,
} from './catalogLookupApi';

const GATEWAY = 'https://gateway.test/api/v1';

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe('API de catálogo', () => {
  it('envía las consultas del catálogo y sus selectores por el Gateway', async () => {
    vi.stubEnv('VITE_API_URL', `${GATEWAY}/`);
    const fetchMock = vi
      .fn()
      .mockImplementation(() => Promise.resolve(Response.json([])));
    vi.stubGlobal('fetch', fetchMock);

    await fetchCatalogSubjects({ universityId: 'u1', careerId: 'c1' });
    await fetchUniversities();
    await fetchCareers('u1');
    await fetchSubjectsByCareer('c1');
    await fetchProfessorsBySubject('s1');
    await fetchCatalogSubjectNames();
    await fetchCatalogProfessorNames();

    expect(fetchMock.mock.calls.map(([url]) => url)).toEqual([
      `${GATEWAY}/catalog/filter?universityId=u1&careerId=c1`,
      `${GATEWAY}/catalog/universities`,
      `${GATEWAY}/catalog/careers?universityId=u1`,
      `${GATEWAY}/catalog/subjects?careerId=c1`,
      `${GATEWAY}/catalog/professors?subjectId=s1`,
      `${GATEWAY}/catalog/subjects`,
      `${GATEWAY}/catalog/professors`,
    ]);
  });

  it('no consulta un origen alternativo cuando falta VITE_API_URL', async () => {
    vi.stubEnv('VITE_API_URL', '');
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    await expect(fetchCatalogSubjects()).rejects.toThrow('VITE_API_URL');
    await expect(fetchCatalogSubjectNames()).rejects.toThrow('VITE_API_URL');
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
