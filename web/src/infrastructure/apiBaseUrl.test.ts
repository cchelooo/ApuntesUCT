import { afterEach, describe, expect, it, vi } from 'vitest';
import { getApiBaseUrl } from './apiBaseUrl';

afterEach(() => {
  vi.unstubAllEnvs();
});

describe('getApiBaseUrl', () => {
  it('usa VITE_API_URL sin barras finales', () => {
    vi.stubEnv('VITE_API_URL', 'https://gateway.test/api/v1///');

    expect(getApiBaseUrl()).toBe('https://gateway.test/api/v1');
  });

  it('falla explícitamente si VITE_API_URL está vacía o solo contiene espacios', () => {
    for (const value of ['', '   ']) {
      vi.stubEnv('VITE_API_URL', value);

      expect(() => getApiBaseUrl()).toThrow('VITE_API_URL');
    }
  });
});
