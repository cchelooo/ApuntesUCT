import type { MaterialListItem } from '../../domain/material/materialListItem';
import type { SearchResultPage } from '../../domain/search/search';
import type { RawSearchPage, RawSearchResult } from './rawSearch';

const UNTITLED = 'Material sin título';

function text(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function integer(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

export function mapRawSearchResult(
  raw: RawSearchResult
): MaterialListItem | null {
  const id = text(raw?.materialId);
  if (!id) return null;
  return {
    id,
    title: text(raw.title) ?? UNTITLED,
    year: integer(raw.academicYear),
    type: text(raw.materialType),
    subjectName: text(raw.subjectName),
    professorName: text(raw.professorName),
    subjectId: text(raw.subjectId),
    professorId: text(raw.professorId),
  };
}

export function mapRawSearchPage(
  raw: RawSearchPage,
  requested: { page: number; pageSize: number }
): SearchResultPage {
  const list = Array.isArray(raw.items)
    ? raw.items
    : Array.isArray(raw.results)
      ? raw.results
      : [];
  const items = list
    .map(mapRawSearchResult)
    .filter((item): item is MaterialListItem => item !== null);

  const pageSize =
    typeof raw.pageSize === 'number' && raw.pageSize > 0
      ? raw.pageSize
      : requested.pageSize;
  const page =
    typeof raw.page === 'number' && raw.page > 0 ? raw.page : requested.page;
  const total =
    typeof raw.total === 'number' && raw.total >= 0 ? raw.total : items.length;

  return {
    items,
    page,
    pageSize,
    total,
    totalPages: Math.max(1, Math.ceil(total / pageSize)),
  };
}
