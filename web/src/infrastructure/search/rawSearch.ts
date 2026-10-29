export interface RawSearchResult {
  id?: string | null;
  title?: string | null;
  academicYear?: number | null;
  materialType?: string | null;
  subjectId?: string | null;
  professorId?: string | null;
  subjectName?: string | null;
  professorName?: string | null;
}

export interface RawSearchPage {
  items?: RawSearchResult[];
  results?: RawSearchResult[];
  page?: number;
  pageSize?: number;
  total?: number;
}
