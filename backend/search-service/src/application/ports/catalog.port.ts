export interface CatalogProfessor {
  id: string;
  name: string;
}

export interface SubjectAcademicContext {
  subjectId: string;
  subjectName: string;
  subjectCode: string | null;
  semester: number | null;
  careerId: string | null;
  careerName: string | null;
  universityId: string | null;
  universityName: string | null;
  professors: CatalogProfessor[];
}

export abstract class CatalogPort {
  abstract getAcademicContext(): Promise<SubjectAcademicContext[]>;
}
