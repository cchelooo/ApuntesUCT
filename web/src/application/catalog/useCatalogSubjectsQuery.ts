import { useQuery } from '@tanstack/react-query';
import {
  fetchCatalogSubjects,
  type CatalogFilters,
} from '../../infrastructure/catalog/catalogApi';
import { mapRawSubjectsToSubjects } from '../../infrastructure/catalog/mapCatalogSubject';

export function useCatalogSubjectsQuery(filters: CatalogFilters = {}) {
  return useQuery({
    queryKey: ['catalog', 'subjects', filters],
    queryFn: () => fetchCatalogSubjects(filters),
    select: mapRawSubjectsToSubjects,
  });
}
