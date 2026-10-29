import { DependencyError } from '../../application/errors/dependency.error';

const DEFAULT_TIMEOUT_MS = 5000;

export async function getJson<T>(url: string, service: string): Promise<T> {
  let response: Response;

  try {
    response = await fetch(url, {
      headers: { accept: 'application/json' },
      signal: AbortSignal.timeout(DEFAULT_TIMEOUT_MS),
    });
  } catch (error) {
    const timedOut =
      error instanceof Error &&
      (error.name === 'TimeoutError' || error.name === 'AbortError');

    throw new DependencyError(
      service,
      timedOut ? 'timeout' : 'unavailable',
      timedOut
        ? `${service} no respondió dentro del tiempo esperado`
        : `${service} no está disponible`,
      { cause: error },
    );
  }

  if (!response.ok) {
    throw new DependencyError(
      service,
      'upstream-error',
      `${service} respondió con estado ${response.status}`,
      { status: response.status },
    );
  }

  try {
    return (await response.json()) as T;
  } catch (error) {
    const timedOut =
      error instanceof Error &&
      (error.name === 'TimeoutError' || error.name === 'AbortError');

    throw new DependencyError(
      service,
      timedOut ? 'timeout' : 'invalid-response',
      timedOut
        ? `${service} no respondió dentro del tiempo esperado`
        : `${service} devolvió una respuesta que no es JSON válido`,
      { cause: error },
    );
  }
}
