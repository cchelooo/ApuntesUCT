export abstract class PersistenceHealthPort {
  abstract check(): Promise<void>;
}
