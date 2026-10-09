import type { MaterialListItem } from '../../domain/material/materialListItem';
import type { MaterialPage } from '../../domain/material/materialPage';
import type { RawMaterial, RawMaterialPage } from './rawMaterial';

const UNTITLED = 'Material sin título';

function text(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function integer(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

export function mapRawMaterial(raw: RawMaterial): MaterialListItem {
  return {
    id: String(raw.id),
    title: text(raw.title) ?? UNTITLED,
    subjectName: text(raw.subjectName) ?? text(raw.subject?.name),
    professorName: text(raw.professorName) ?? text(raw.professor?.name),
    year: integer(raw.year),
    type: text(raw.type),
  };
}

export function mapRawMaterialPage(raw: RawMaterialPage): MaterialPage {
  const pageSize = raw.pageSize > 0 ? raw.pageSize : 1;
  return {
    items: raw.items
      .filter((item) => item && item.id !== undefined && item.id !== null)
      .map(mapRawMaterial),
    page: raw.page,
    pageSize,
    total: raw.total,
    totalPages: Math.max(1, Math.ceil(raw.total / pageSize)),
  };
}
