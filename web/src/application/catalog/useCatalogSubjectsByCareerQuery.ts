import { useQuery } from '@tanstack/react-query';
import { fetchSubjectsByCareer } from '../../infrastructure/catalog/catalogApi';

export function useCatalogSubjectsByCareerQuery(careerId?: string) {
  return useQuery({
    queryKey: ['catalog', 'subjectsByCareer', careerId],
    queryFn: () => fetchSubjectsByCareer(careerId!),
    enabled: !!careerId,
  });
}
