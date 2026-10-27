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

export const SEARCH_TYPE_OPTIONS: ReadonlyArray<{
  value: string;
  label: string;
}> = [
  { value: 'DOCUMENT', label: 'Documento / guía' },
  { value: 'PRESENTATION', label: 'Presentación' },
  { value: 'EXAM', label: 'Evaluación' },
  { value: 'SUMMARY', label: 'Resumen' },
  { value: 'LINK', label: 'Enlace' },
];

export function isSearchType(value: unknown): value is string {
  return SEARCH_TYPE_OPTIONS.some((option) => option.value === value);
}

export function isValidSearchYear(value: string): boolean {
  return /^(19|20)\d{2}$/.test(value);
}

export interface SearchFilters {
  universityId: string;
  careerId: string;
  subjectId: string;
  professorId: string;
  year: string;
  type: string;
}

export const EMPTY_SEARCH_FILTERS: SearchFilters = {
  universityId: '',
  careerId: '',
  subjectId: '',
  professorId: '',
  year: '',
  type: '',
};

export const SEARCH_FILTER_KEYS = Object.keys(EMPTY_SEARCH_FILTERS) as Array<
  keyof SearchFilters
>;

export function hasActiveSearchFilters(filters: SearchFilters): boolean {
  return SEARCH_FILTER_KEYS.some((key) => filters[key] !== '');
}

export interface SearchParams {
  q: string;
  sort?: SearchSort;
  page?: number;
  pageSize?: number;
  filters?: Partial<SearchFilters>;
}

export interface SearchResultPage {
  items: MaterialListItem[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}
