import { useQuery } from '@tanstack/react-query';
import { fetchProfessorsBySubject } from '../../infrastructure/catalog/catalogApi';

export function useCatalogProfessorsQuery(subjectId?: string) {
  return useQuery({
    queryKey: ['catalog', 'professors', subjectId],
    queryFn: () => fetchProfessorsBySubject(subjectId!),
    enabled: !!subjectId,
  });
}
