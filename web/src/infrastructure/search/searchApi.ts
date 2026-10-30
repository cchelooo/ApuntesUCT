import {
  DEFAULT_SEARCH_SORT,
  SEARCH_FILTER_KEYS,
  type SearchParams,
  type SearchSort,
  type SearchResultPage,
} from '../../domain/search/search';
import { MaterialRequestError } from '../material/materialApi';
import { mapRawSearchPage } from './mapSearch';
import type { RawSearchPage } from './rawSearch';

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
  const envUrl = import.meta.env.VITE_API_URL;
  if (envUrl === '') {
    throw new Error('VITE_API_URL is not configured');
  }
  const baseUrl = envUrl ?? 'http://localhost:3000/api/v1';
  return `${baseUrl.replace(/\/+$/, '')}/search`;
}

export async function fetchSearch(
  {
    q,
    sort = DEFAULT_SEARCH_SORT,
    page = 1,
    pageSize = DEFAULT_SEARCH_PAGE_SIZE,
    filters = {},
  }: SearchParams,
  signal?: AbortSignal
): Promise<SearchResultPage> {
  const params = new URLSearchParams({
    q,
    ...SEARCH_API_SORT[sort],
    page: String(page),
    pageSize: String(pageSize),
  });

  for (const key of SEARCH_FILTER_KEYS) {
    const value = filters[key]?.trim();
    if (value) params.set(key, value);
  }

  let response: Response;
  try {
    response = await fetch(`${getSearchUrl()}?${params.toString()}`, {
      signal,
    });
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

  return mapRawSearchPage(body as RawSearchPage, { page, pageSize });
}
