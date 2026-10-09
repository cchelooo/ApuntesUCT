export interface StoredObject {
  /** Referencia interna para persistencia; no se debe serializar en respuestas HTTP. */
  storageKey: string;
}

export abstract class ObjectStorage {
  abstract save(content: Buffer, contentType: string): Promise<StoredObject>;
}

export class ObjectStorageError extends Error {
  constructor() {
    super('No se pudo almacenar el archivo.');
    this.name = 'ObjectStorageError';
  }
}
