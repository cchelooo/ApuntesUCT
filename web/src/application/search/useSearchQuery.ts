import { keepPreviousData, useQuery } from '@tanstack/react-query';
import {
  hasSearchFilters,
  normalizeSearchFilters,
  type SearchParams,
} from '../../domain/search/search';
import { fetchSearch } from '../../infrastructure/search/searchApi';

export function useSearchQuery(params: SearchParams) {
  const q = params.q.trim();
  const filters = normalizeSearchFilters(params.filters ?? {});
  return useQuery({
    queryKey: ['search', { ...params, q, filters }],
    queryFn: ({ signal }) => fetchSearch({ ...params, q, filters }, signal),
    enabled: q.length > 0 || hasSearchFilters(filters),
    placeholderData: keepPreviousData,
  });
}
