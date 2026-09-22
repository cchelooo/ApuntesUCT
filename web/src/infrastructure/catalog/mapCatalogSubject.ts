import type { Subject } from '../../domain/catalog/subject';
import type { RawCatalogSubject } from './rawCatalogSubject';

const UNKNOWN_CAREER = 'Carrera no disponible';
const UNKNOWN_PROFESSOR = 'Profesor no asignado';

function formatProfessorNames(
  professors: RawCatalogSubject['professors']
): string {
  if (!professors || professors.length === 0) {
    return UNKNOWN_PROFESSOR;
  }
  return professors.map((professor) => professor.name).join(', ');
}

export function mapRawSubjectToSubject(raw: RawCatalogSubject): Subject {
  return {
    id: raw.id,
    code: raw.code,
    name: raw.name,
    careerName: raw.career?.name ?? UNKNOWN_CAREER,
    semester: raw.semester ?? 1,
    professorName: formatProfessorNames(raw.professors),
    notesCount: raw.notesCount ?? 0,
  };
}

export function mapRawSubjectsToSubjects(
  rawSubjects: RawCatalogSubject[]
): Subject[] {
  return rawSubjects.map(mapRawSubjectToSubject);
}
