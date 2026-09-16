import { useMemo, useState } from 'react';
import type { Subject } from '../../domain/catalog/subject';
import { subjectsMock } from '../../infrastructure/catalog/subjects.mock';

interface UseCatalogSubjectsResult {
  subjects: Subject[];
  query: string;
  setQuery: (value: string) => void;
  total: number;
}
function normalizeText(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}
export function useCatalogSubjects(): UseCatalogSubjectsResult {
  const [query, setQuery] = useState('');

  const subjects = useMemo(() => {
    const normalized = normalizeText(query);
    if (!normalized) return subjectsMock;

    return subjectsMock.filter(
      (subject) =>
        normalizeText(subject.name).includes(normalized) ||
        normalizeText(subject.code).includes(normalized)
    );
  }, [query]);

  return { subjects, query, setQuery, total: subjectsMock.length };
}
