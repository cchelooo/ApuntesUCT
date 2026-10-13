export interface AcademicReferences {
  subjectId: string;
  careerId?: string;
  professorId?: string;
  universityId: string | null;
}

export abstract class CatalogPort {
  abstract validateReferences(references: AcademicReferences): Promise<void>;
}

export class InvalidAcademicReferenceError extends Error {
  constructor(
    public readonly field: keyof AcademicReferences,
    message: string,
  ) {
    super(message);
    this.name = 'InvalidAcademicReferenceError';
  }
}

export class CatalogUnavailableError extends Error {
  constructor() {
    super('No se pudo validar las referencias académicas mediante Catalog.');
    this.name = 'CatalogUnavailableError';
  }
}
