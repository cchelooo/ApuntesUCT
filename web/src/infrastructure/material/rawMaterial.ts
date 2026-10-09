export interface RawMaterial {
  id: string;
  title?: string | null;
  year?: number | null;
  type?: string | null;
  subjectId?: string | null;
  subjectName?: string | null;
  subject?: { name?: string | null } | null;
  professorName?: string | null;
  professor?: { name?: string | null } | null;
}

export interface RawMaterialPage {
  items: RawMaterial[];
  page: number;
  pageSize: number;
  total: number;
}
