import { useQuery } from '@tanstack/react-query';
import { fetchCareers } from '../../infrastructure/catalog/catalogApi';

export function useCatalogCareersQuery(universityId?: string) {
  return useQuery({
    queryKey: ['catalog', 'careers', universityId],
    queryFn: () => fetchCareers(universityId!),
    enabled: !!universityId,
  });
}
