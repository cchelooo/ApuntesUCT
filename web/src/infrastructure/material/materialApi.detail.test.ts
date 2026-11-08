import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  buildMaterialDownloadUrl,
  fetchMaterial,
  isMaterialNotFound,
  MaterialRequestError,
} from './materialApi';

const GATEWAY = 'https://gateway.test/api/v1';

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe('materialApi: detalle y URL de descarga', () => {
  it('construye la URL de descarga con VITE_API_URL y sin barra duplicada', () => {
    vi.stubEnv('VITE_API_URL', `${GATEWAY}/`);
    expect(buildMaterialDownloadUrl('a/b')).toBe(
      `${GATEWAY}/materials/a%2Fb/download`
    );
  });

  it('detecta la ausencia de configuración antes de pedir nada', async () => {
    vi.stubEnv('VITE_API_URL', '');
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    expect(() => buildMaterialDownloadUrl('x')).toThrow('VITE_API_URL');
    await expect(fetchMaterial('x')).rejects.toThrow('VITE_API_URL');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('un 404 produce un error con status y se reconoce como "no encontrado"', async () => {
    vi.stubEnv('VITE_API_URL', GATEWAY);
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValue(
          Response.json({ message: 'Material no encontrado.' }, { status: 404 })
        )
    );

    const error = await fetchMaterial('x').catch((e: unknown) => e);
    expect(error).toBeInstanceOf(MaterialRequestError);
    expect(error).toMatchObject({ status: 404 });
    expect((error as Error).message).toBe(
      'Error al consultar Material Service (status 404): Material no encontrado.'
    );
    expect(isMaterialNotFound(error)).toBe(true);
  });

  it('un 500 no se considera "no encontrado"', () => {
    expect(
      isMaterialNotFound(new MaterialRequestError('x', { status: 500 }))
    ).toBe(false);
    expect(isMaterialNotFound(new Error('red'))).toBe(false);
  });
});
