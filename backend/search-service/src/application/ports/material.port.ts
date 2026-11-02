export interface MaterialCandidate {
  id: string;
  title: string;
  description: string | null;
  materialType: string | null;
  academicYear: number | null;
  verified: boolean;
  subjectId: string | null;
  careerId: string | null;
  universityId: string | null;
  professorId: string | null;
  createdAt: string | null;
  updatedAt: string | null;
}

export interface MaterialPage {
  items: MaterialCandidate[];
  page: number;
  pageSize: number;
  total: number;
}

export interface MaterialPageQuery {
  page: number;
  pageSize: number;
}

export abstract class MaterialPort {
  abstract findCandidates(query: MaterialPageQuery): Promise<MaterialPage>;
}
