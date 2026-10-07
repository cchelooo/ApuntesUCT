import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  createMaterial,
  downloadMaterial,
  fetchMaterial,
  fetchMaterials,
} from './materialApi';

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe('materialApi', () => {
  it('gets paginated materials through VITE_API_URL', async () => {
    vi.stubEnv('VITE_API_URL', 'https://api.example.test/api/v1/');
    const fetchMock = vi.fn().mockResolvedValue(
      Response.json({ items: [], page: 2, pageSize: 10, total: 0 })
    );
    vi.stubGlobal('fetch', fetchMock);

    await expect(fetchMaterials({ page: 2, pageSize: 10 })).resolves.toEqual({
      items: [],
      page: 2,
      pageSize: 10,
      total: 0,
    });
    expect(fetchMock).toHaveBeenCalledWith(
      'https://api.example.test/api/v1/materials?page=2&pageSize=10'
    );
  });

  it('gets a material detail through the Gateway', async () => {
    vi.stubEnv('VITE_API_URL', 'https://api.example.test/api/v1');
    const fetchMock = vi.fn().mockResolvedValue(Response.json({ id: 'id/1' }));
    vi.stubGlobal('fetch', fetchMock);

    await fetchMaterial('id/1');

    expect(fetchMock).toHaveBeenCalledWith(
      'https://api.example.test/api/v1/materials/id%2F1'
    );
  });

  it('posts metadata and an optional file as multipart form data', async () => {
    vi.stubEnv('VITE_API_URL', 'https://api.example.test/api/v1');
    const fetchMock = vi.fn().mockResolvedValue(
      Response.json({ status: 'success', message: 'created', data: {} })
    );
    vi.stubGlobal('fetch', fetchMock);

    const file = new File(['pdf'], 'notes.pdf', { type: 'application/pdf' });
    await createMaterial({
      title: 'Notes',
      year: '2026',
      type: 'DOCUMENT',
      subjectId: 'subject-1',
      file,
    });

    const [, options] = fetchMock.mock.calls[0] as [
      string,
      RequestInit,
    ];
    expect(options.method).toBe('POST');
    expect(options.headers).toBeUndefined();
    expect(options.body).toBeInstanceOf(FormData);
    expect((options.body as FormData).get('file')).toBe(file);
  });

  it('returns downloaded content and rejects failed responses', async () => {
    vi.stubEnv('VITE_API_URL', 'https://api.example.test/api/v1');
    const file = new Blob(['file contents']);
    const successResponse = Response.json({});
    vi.spyOn(successResponse, 'blob').mockResolvedValue(file);
    const fetchMock = vi.fn().mockResolvedValue(successResponse);
    vi.stubGlobal('fetch', fetchMock);

    await expect(downloadMaterial('material-1')).resolves.toBeInstanceOf(Blob);
    expect(fetchMock).toHaveBeenCalledWith(
      'https://api.example.test/api/v1/materials/material-1/download'
    );

    fetchMock.mockResolvedValueOnce(
      Response.json({ message: 'Material no encontrado' }, { status: 404 })
    );
    await expect(fetchMaterial('missing')).rejects.toThrow(
      'Error al consultar Material Service (status 404): Material no encontrado'
    );
  });
});
