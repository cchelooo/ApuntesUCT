import { useQuery } from '@tanstack/react-query';
import type { CatalogNames } from '../../domain/catalog/catalogNames';
import {
  fetchCatalogProfessorNames,
  fetchCatalogSubjectNames,
} from '../../infrastructure/catalog/catalogLookupApi';

function toRecord(entities: Array<{ id: string; name: string }>) {
  return Object.fromEntries(entities.map((entity) => [entity.id, entity.name]));
}

export function useCatalogNamesQuery() {
  return useQuery<CatalogNames>({
    queryKey: ['catalog', 'names'],
    queryFn: async ({ signal }) => {
      const [subjects, professors] = await Promise.all([
        fetchCatalogSubjectNames(signal),
        fetchCatalogProfessorNames(signal),
      ]);
      return { subjects: toRecord(subjects), professors: toRecord(professors) };
    },
    staleTime: 5 * 60 * 1000,
  });
}
