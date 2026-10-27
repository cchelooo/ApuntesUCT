export type DependencyFailure =
  | 'unavailable'
  | 'timeout'
  | 'upstream-error'
  | 'invalid-response';

interface DependencyErrorOptions {
  status?: number;
  cause?: unknown;
}

export class DependencyError extends Error {
  readonly status?: number;
  readonly cause?: unknown;

  constructor(
    readonly service: string,
    readonly failure: DependencyFailure,
    message: string,
    options: DependencyErrorOptions = {},
  ) {
    super(message);
    this.name = 'DependencyError';
    this.status = options.status;
    this.cause = options.cause;
  }
}
