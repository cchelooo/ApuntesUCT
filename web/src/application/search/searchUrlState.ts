import {
  DEFAULT_SEARCH_SORT,
  isSearchSort,
  normalizeSearchFilters,
  parseSearchYear,
  type SearchFilters,
  type SearchSort,
} from '../../domain/search/search';

export interface SearchUrlState {
  q: string;
  sort: SearchSort;
  page: number;
  filters: SearchFilters;
}

function parsePage(value: string | null): number {
  const page = Number(value);
  return Number.isInteger(page) && page >= 1 ? page : 1;
}

export function parseSearchUrl(params: URLSearchParams): SearchUrlState {
  const sortParam = params.get('sort');
  return {
    q: (params.get('q') ?? '').trim(),
    sort: isSearchSort(sortParam) ? sortParam : DEFAULT_SEARCH_SORT,
    page: parsePage(params.get('page')),
    filters: normalizeSearchFilters({
      universityId: params.get('universityId') ?? undefined,
      careerId: params.get('careerId') ?? undefined,
      subjectId: params.get('subjectId') ?? undefined,
      professorId: params.get('professorId') ?? undefined,
      year: parseSearchYear(params.get('year')),
      type: params.get('type') ?? undefined,
    }),
  };
}

export function buildSearchParams(state: SearchUrlState): URLSearchParams {
  const params = new URLSearchParams();
  const filters = normalizeSearchFilters(state.filters);
  if (state.q) params.set('q', state.q);
  params.set('sort', state.sort);
  if (state.page > 1) params.set('page', String(state.page));
  if (filters.universityId) params.set('universityId', filters.universityId);
  if (filters.careerId) params.set('careerId', filters.careerId);
  if (filters.subjectId) params.set('subjectId', filters.subjectId);
  if (filters.professorId) params.set('professorId', filters.professorId);
  if (filters.year !== undefined) params.set('year', String(filters.year));
  if (filters.type) params.set('type', filters.type);
  return params;
}
