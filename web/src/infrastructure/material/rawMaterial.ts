export interface RawMaterial {
  id: string;
  title?: string | null;
  academicYear?: number | null;
  materialType?: string | null;
  subjectId?: string | null;
  professorId?: string | null;
}

export interface RawMaterialPage {
  items: RawMaterial[];
  page: number;
  pageSize: number;
  total: number;
}
