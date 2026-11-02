import {
  DEFAULT_SEARCH_SORT,
  normalizeSearchFilters,
  type SearchParams,
  type SearchSort,
  type SearchResultPage,
} from '../../domain/search/search';
import { MaterialRequestError } from '../material/materialApi';
import { mapRawSearchPage } from './mapSearch';
import type { RawSearchPage } from './rawSearch';
import { getApiBaseUrl } from '../apiBaseUrl';

export const DEFAULT_SEARCH_PAGE_SIZE = 20;

const SEARCH_API_SORT: Record<
  SearchSort,
  { sortBy: 'createdAt' | 'year' | 'title'; order: 'asc' | 'desc' }
> = {
  recent: { sortBy: 'createdAt', order: 'desc' },
  year_desc: { sortBy: 'year', order: 'desc' },
  title: { sortBy: 'title', order: 'asc' },
};

function getSearchUrl(): string {
  return `${getApiBaseUrl()}/search`;
}

export function buildSearchQuery({
  q,
  sort = DEFAULT_SEARCH_SORT,
  page = 1,
  pageSize = DEFAULT_SEARCH_PAGE_SIZE,
  filters,
}: SearchParams): URLSearchParams {
  const params = new URLSearchParams();
  if (q.trim()) params.set('q', q.trim());

  const normalized = normalizeSearchFilters(filters ?? {});
  if (normalized.universityId)
    params.set('universityId', normalized.universityId);
  if (normalized.careerId) params.set('careerId', normalized.careerId);
  if (normalized.subjectId) params.set('subjectId', normalized.subjectId);
  if (normalized.professorId) params.set('professorId', normalized.professorId);
  if (normalized.year !== undefined)
    params.set('year', String(normalized.year));
  if (normalized.type) params.set('type', normalized.type);

  const { sortBy, order } = SEARCH_API_SORT[sort];
  params.set('sortBy', sortBy);
  params.set('order', order);
  params.set('page', String(page));
  params.set('pageSize', String(pageSize));
  return params;
}

export async function fetchSearch(
  searchParams: SearchParams,
  signal?: AbortSignal
): Promise<SearchResultPage> {
  const params = buildSearchQuery(searchParams);

  const url = `${getSearchUrl()}?${params.toString()}`;
  let response: Response;
  try {
    response = await fetch(url, { signal });
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw error;
    }
    throw new MaterialRequestError('Fallo de red al buscar materiales', {
      isNetworkError: true,
    });
  }

  if (!response.ok) {
    throw new MaterialRequestError(
      `No se pudo completar la búsqueda (status ${response.status})`,
      { status: response.status }
    );
  }

  const body: unknown = await response.json();
  if (typeof body !== 'object' || body === null) {
    throw new MaterialRequestError(
      'La respuesta de búsqueda no tiene el formato esperado',
      {}
    );
  }

  return mapRawSearchPage(body as RawSearchPage, {
    page: searchParams.page ?? 1,
    pageSize: searchParams.pageSize ?? DEFAULT_SEARCH_PAGE_SIZE,
  });
}
