import type { CatalogNames } from '../../domain/catalog/catalogNames';
import type { MaterialListItem } from '../../domain/material/materialListItem';

function lookup(
  dictionary: Record<string, string>,
  id: string | null | undefined
): string | null {
  if (!id || !Object.prototype.hasOwnProperty.call(dictionary, id)) return null;
  return dictionary[id] ?? null;
}

export function resolveMaterialNames(
  items: MaterialListItem[],
  names?: CatalogNames
): MaterialListItem[] {
  if (!names) return items;
  return items.map((item) => ({
    ...item,
    subjectName: item.subjectName ?? lookup(names.subjects, item.subjectId),
    professorName:
      item.professorName ?? lookup(names.professors, item.professorId),
  }));
}
