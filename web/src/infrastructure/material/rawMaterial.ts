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

export interface RawMaterialVersion {
  versionNumber?: number | null;
  originalFilename?: string | null;
  mimeType?: string | null;
  fileSize?: number | string | null;
  createdAt?: string | null;
}

export interface RawMaterialDetail extends RawMaterial {
  description?: string | null;
  externalLink?: string | null;
  currentVersion?: RawMaterialVersion | null;
  versions?: RawMaterialVersion[] | null;
}
