import type { RawCatalogSubject } from './rawCatalogSubject';
 
const baseUrl = import.meta.env.VITE_CATALOG_API_URL ?? 'http://localhost:3002/api/v1';
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
  filters: CatalogFilters = {},
): Promise<RawCatalogSubject[]> {
  const response = await fetch(`${baseUrl}/catalog/filter${buildQuery(filters)}`);
 
  if (!response.ok) {
    throw new Error(`No se pudo obtener el catálogo (status ${response.status})`);
  }
 
  return response.json() as Promise<RawCatalogSubject[]>;
}