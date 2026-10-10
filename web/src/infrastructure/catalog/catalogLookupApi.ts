const baseUrl = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

interface NamedEntity {
  id: string;
  name: string;
}

async function fetchNamedEntities(
  resource: 'subjects' | 'professors',
  signal?: AbortSignal
): Promise<NamedEntity[]> {
  const response = await fetch(`${baseUrl}/catalog/${resource}`, { signal });
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
