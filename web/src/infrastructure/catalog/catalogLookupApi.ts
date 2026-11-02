import { getApiBaseUrl } from '../apiBaseUrl';

interface NamedEntity {
  id: string;
  name: string;
}

async function fetchNamedEntities(
  resource: 'subjects' | 'professors',
  signal?: AbortSignal
): Promise<NamedEntity[]> {
  const response = await fetch(`${getApiBaseUrl()}/catalog/${resource}`, {
    signal,
  });
  if (!response.ok) {
    throw new Error(
      `No se pudo obtener ${resource} del catálogo (status ${response.status})`
    );
  }
  return (await response.json()) as NamedEntity[];
}

export function fetchCatalogSubjectNames(signal?: AbortSignal) {
  return fetchNamedEntities('subjects', signal);
}

export function fetchCatalogProfessorNames(signal?: AbortSignal) {
  return fetchNamedEntities('professors', signal);
}
