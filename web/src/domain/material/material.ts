export type MaterialViewStatus =
  | 'ready'
  | 'loading'
  | 'unavailable'
  | 'not-found';
 
export interface MaterialVersion {
  number: number;
  uploadedAt: string | null;
  uploadedBy: string | null;
  fileFormat: string | null;
  fileSizeLabel: string | null;
}
 
export interface MaterialDetail {
  id: string;
  title: string;
  description: string | null;
  type: string | null;
  year: number | null;
  subjectName: string | null;
  professorName: string | null;
  version: MaterialVersion | null;
  downloadUrl: string | null;
}