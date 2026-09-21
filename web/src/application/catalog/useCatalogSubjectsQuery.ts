import { useQuery } from '@tanstack/react-query';
import { fetchCatalogSubjects, type CatalogFilters } from '../../infrastructure/catalog/catalogApi';

export function useCatalogSubjectsQuery(filters: CatalogFilters = {}) {
  return useQuery({
    queryKey: ['catalog', 'subjects', filters],
    queryFn: () => fetchCatalogSubjects(filters),
  });
}