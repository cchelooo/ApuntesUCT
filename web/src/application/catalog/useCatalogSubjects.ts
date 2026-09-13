import { useMemo, useState } from 'react';
import type { Subject } from '../../domain/catalog/subject';
import { subjectsMock } from '../../infrastructure/catalog/subjects.mock';
 
interface UseCatalogSubjectsResult {
  subjects: Subject[];
  query: string;
  setQuery: (value: string) => void;
  total: number;
}
export function useCatalogSubjects(): UseCatalogSubjectsResult {
  const [query, setQuery] = useState('');
 
  const subjects = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) return subjectsMock;
 
    return subjectsMock.filter(
      (subject) =>
        subject.name.toLowerCase().includes(normalized) ||
        subject.code.toLowerCase().includes(normalized),
    );
  }, [query]);
 
  return { subjects, query, setQuery, total: subjectsMock.length };
}