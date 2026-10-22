import { keepPreviousData, useQuery } from '@tanstack/react-query';
import type { SearchParams } from '../../domain/search/search';
import { fetchSearch } from '../../infrastructure/search/searchApi';

export function useSearchQuery(params: SearchParams) {
  const q = params.q.trim();
  return useQuery({
    queryKey: ['search', { ...params, q }],
    queryFn: ({ signal }) => fetchSearch({ ...params, q }, signal),
    enabled: q.length > 0,
    placeholderData: keepPreviousData,
  });
}
