import type { RawCatalogSubject } from './rawCatalogSubject';

const baseUrl = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';
export interface CatalogFilters {
  universityId?: string;
  careerId?: string;
  subjectId?: string;
  professorId?: string;
}

function buildQuery(filters: CatalogFilters): string {
  const params = new URLSearchParams();

  if (filters.universityId) params.set('universityId', filters.universityId);
  if (filters.careerId) params.set('careerId', filters.careerId);
  if (filters.subjectId) params.set('subjectId', filters.subjectId);
  if (filters.professorId) params.set('professorId', filters.professorId);

  const query = params.toString();
  return query ? `?${query}` : '';
}

export async function fetchCatalogSubjects(
  filters: CatalogFilters = {}
): Promise<RawCatalogSubject[]> {
  const response = await fetch(
    `${baseUrl}/catalog/filter${buildQuery(filters)}`
  );

  if (!response.ok) {
    throw new Error(
      `No se pudo obtener el catálogo (status ${response.status})`
    );
  }

  return response.json() as Promise<RawCatalogSubject[]>;
}

export async function fetchUniversities(): Promise<
  import('../../domain/catalog/university').University[]
> {
  const response = await fetch(`${baseUrl}/catalog/universities`);
  if (!response.ok) {
    throw new Error(
      `No se pudieron obtener las universidades (status ${response.status})`
    );
  }
  return response.json();
}

export async function fetchCareers(
  universityId: string
): Promise<import('../../domain/catalog/career').Career[]> {
  const response = await fetch(
    `${baseUrl}/catalog/careers?universityId=${universityId}`
  );
  if (!response.ok) {
    throw new Error(
      `No se pudieron obtener las carreras (status ${response.status})`
    );
  }
  return response.json();
}

export async function fetchSubjectsByCareer(
  careerId: string
): Promise<import('../../domain/catalog/subject').Subject[]> {
  const response = await fetch(
    `${baseUrl}/catalog/subjects?careerId=${careerId}`
  );
  if (!response.ok) {
    throw new Error(
      `No se pudieron obtener las asignaturas (status ${response.status})`
    );
  }
  return response.json();
}

export async function fetchProfessorsBySubject(
  subjectId: string
): Promise<import('../../domain/catalog/professor').Professor[]> {
  const response = await fetch(
    `${baseUrl}/catalog/professors?subjectId=${subjectId}`
  );
  if (!response.ok) {
    throw new Error(
      `No se pudieron obtener los profesores (status ${response.status})`
    );
  }
  return response.json();
}
