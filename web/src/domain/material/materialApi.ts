export type MaterialKind = 'DOCUMENT' | 'PRESENTATION' | 'LINK';

export interface MaterialSummary {
  id: string;
  title: string;
  description: string | null;
  uploaderId: string;
  academicOfferingId: string | null;
  universityId: string | null;
  careerId: string | null;
  subjectId: string;
  professorId: string | null;
  materialTypeId: string;
  materialType: string;
  academicYear: number;
  status: 'PUBLISHED';
  verified: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface MaterialPage {
  items: MaterialSummary[];
  page: number;
  pageSize: number;
  total: number;
}

export interface ListMaterialsParams {
  page?: number;
  pageSize?: number;
}

export interface CreateMaterialRequest {
  title: string;
  description?: string;
  year: string;
  type: MaterialKind;
  subjectId: string;
  careerId?: string;
  professor?: string;
  externalLink?: string;
  file?: File;
}

export interface CreatedMaterial {
  id: string;
  title: string;
  description: string | null;
  year: string;
  type: MaterialKind;
  subjectId: string;
  careerId?: string | null;
  professor?: string | null;
  fileUrl: string | null;
  fileSize: number | null;
  mimeType: string | null;
  externalLink: string | null;
  createdAt: string;
}

export interface CreateMaterialResponse {
  status: 'success';
  isSimulatedResponse?: boolean;
  message: string;
  data: CreatedMaterial;
}

// The backend has not published a separate detail schema yet.
export type MaterialDetailResponse = MaterialSummary;
