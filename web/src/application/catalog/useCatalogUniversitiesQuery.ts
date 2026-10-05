import { useQuery } from '@tanstack/react-query';
import { fetchUniversities } from '../../infrastructure/catalog/catalogApi';

export function useCatalogUniversitiesQuery() {
  return useQuery({
    queryKey: ['catalog', 'universities'],
    queryFn: fetchUniversities,
  });
}
