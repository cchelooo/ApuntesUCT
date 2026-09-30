import { useMemo, useState } from 'react';
import type { Subject } from '../../domain/catalog/subject';
import { useCatalogSubjectsQuery } from './useCatalogSubjectsQuery';

interface UseCatalogSubjectsResult {
  subjects: Subject[];
  query: string;
  setQuery: (value: string) => void;
  total: number;
  isLoading: boolean;
  isError: boolean;
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
  const { data, isLoading, isError } = useCatalogSubjectsQuery();

  const allSubjects = useMemo(() => data ?? [], [data]);

  const subjects = useMemo(() => {
    const normalized = normalizeText(query);
    if (!normalized) return allSubjects;

    return allSubjects.filter(
      (subject) =>
        normalizeText(subject.name).includes(normalized) ||
        normalizeText(subject.code).includes(normalized)
    );
  }, [allSubjects, query]);

  return {
    subjects,
    query,
    setQuery,
    total: allSubjects.length,
    isLoading,
    isError,
  };
}
