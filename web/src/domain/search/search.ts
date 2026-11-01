import type { MaterialListItem } from '../material/materialListItem';

export type SearchSort = 'recent' | 'year_desc' | 'title';

export const DEFAULT_SEARCH_SORT: SearchSort = 'recent';

export const SEARCH_SORT_OPTIONS: ReadonlyArray<{
  value: SearchSort;
  label: string;
}> = [
  { value: 'recent', label: 'Más recientes' },
  { value: 'year_desc', label: 'Año (mayor a menor)' },
  { value: 'title', label: 'Título (A-Z)' },
];

export function isSearchSort(value: unknown): value is SearchSort {
  return SEARCH_SORT_OPTIONS.some((option) => option.value === value);
}

export const SEARCH_YEAR_MIN = 1900;
export const SEARCH_YEAR_MAX = 2099;

export interface SearchFilters {
  universityId?: string;
  careerId?: string;
  subjectId?: string;
  professorId?: string;
  year?: number;
  type?: string;
}

export const SEARCH_TYPE_OPTIONS: ReadonlyArray<{
  value: string;
  label: string;
}> = [
  { value: '', label: 'Todos los tipos' },
  { value: 'DOCUMENT', label: 'Documento / guía' },
  { value: 'PRESENTATION', label: 'Presentación' },
  { value: 'EXAM', label: 'Evaluación' },
  { value: 'SUMMARY', label: 'Resumen' },
  { value: 'LINK', label: 'Enlace' },
];

export function parseSearchYear(
  value: string | null | undefined
): number | undefined {
  const text = value?.trim();
  if (!text || !/^\d{4}$/.test(text)) return undefined;
  const year = Number(text);
  return year >= SEARCH_YEAR_MIN && year <= SEARCH_YEAR_MAX ? year : undefined;
}

function clean(value?: string): string | undefined {
  return value?.trim() || undefined;
}

export function normalizeSearchFilters(filters: SearchFilters): SearchFilters {
  const universityId = clean(filters.universityId);
  const careerId = universityId ? clean(filters.careerId) : undefined;
  const subjectId = careerId ? clean(filters.subjectId) : undefined;
  const professorId = subjectId ? clean(filters.professorId) : undefined;
  const year =
    filters.year !== undefined &&
    Number.isInteger(filters.year) &&
    filters.year >= SEARCH_YEAR_MIN &&
    filters.year <= SEARCH_YEAR_MAX
      ? filters.year
      : undefined;
  return {
    universityId,
    careerId,
    subjectId,
    professorId,
    year,
    type: clean(filters.type),
  };
}

export function hasSearchFilters(filters: SearchFilters = {}): boolean {
  return Object.values(normalizeSearchFilters(filters)).some(
    (value) => value !== undefined
  );
}

export interface SearchParams {
  q: string;
  sort?: SearchSort;
  page?: number;
  pageSize?: number;
  filters?: SearchFilters;
}

export interface SearchResultPage {
  items: MaterialListItem[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}
