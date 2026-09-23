export interface RawCatalogSubject {
  id: string;
  careerId: string;
  code: string;
  name: string;
  description: string | null;
  semester?: number;
  active: boolean;
  createdAt: string;
  updatedAt: string;
  career?: {
    id: string;
    name: string;
    code: string;
    university?: {
      id: string;
      name: string;
      code: string;
    };
  };
  professors?: Array<{
    id: string;
    name: string;
    email: string;
  }>;
  notesCount?: number;
}
