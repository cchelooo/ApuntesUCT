export interface StoredObject {
  /** Referencia interna para persistencia; no se debe serializar en respuestas HTTP. */
  storageKey: string;
}

export abstract class ObjectStorage {
  abstract remove(storageKey: string): Promise<void>;
  abstract save(content: Buffer, contentType: string): Promise<StoredObject>;
}

export class ObjectStorageError extends Error {
  constructor() {
    super('No se pudo completar la operación de almacenamiento.');
    this.name = 'ObjectStorageError';
  }
}
