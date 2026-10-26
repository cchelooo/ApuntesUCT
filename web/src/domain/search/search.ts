import type { MaterialListItem } from '../material/materialListItem';

export type SearchSort = 'relevance' | 'recent' | 'year_desc' | 'title';

export const DEFAULT_SEARCH_SORT: SearchSort = 'relevance';

export const SEARCH_SORT_OPTIONS: ReadonlyArray<{
  value: SearchSort;
  label: string;
}> = [
  { value: 'relevance', label: 'Más relevantes' },
  { value: 'recent', label: 'Más recientes' },
  { value: 'year_desc', label: 'Año (mayor a menor)' },
  { value: 'title', label: 'Título (A-Z)' },
];

export function isSearchSort(value: unknown): value is SearchSort {
  return SEARCH_SORT_OPTIONS.some((option) => option.value === value);
}

export interface SearchParams {
  q: string;
  sort?: SearchSort;
  page?: number;
  pageSize?: number;
}

export interface SearchResultPage {
  items: MaterialListItem[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}
