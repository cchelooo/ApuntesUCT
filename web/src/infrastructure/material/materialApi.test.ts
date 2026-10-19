import type {
  CreateMaterialResponse,
  MaterialKind,
} from '../../domain/material/materialApi';
import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  createMaterial,
  downloadMaterial,
  fetchMaterial,
  fetchMaterials,
} from './materialApi';

const createdResponse: CreateMaterialResponse = {
  status: 'success',
  isSimulatedResponse: false,
  message: 'Material registrado',
  data: {
    id: 'material-1',
    title: 'Notes',
    year: '2026',
    type: 'DOCUMENT',
    status: 'PENDING_REVIEW',
    subjectId: 'subject-1',
    professorId: 'prof-1',
    careerId: null,
    universityId: null,
    description: null,
    fileUrl: null,
    fileSize: 3,
    mimeType: 'application/pdf',
    externalLink: null,
    createdAt: '2026-10-12T12:00:00.000Z',
  },
};

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe('materialApi', () => {
  it('gets paginated materials through VITE_API_URL', async () => {
    vi.stubEnv('VITE_API_URL', 'https://api.example.test/api/v1/');
    const fetchMock = vi
      .fn()
      .mockResolvedValue(
        Response.json({ items: [], page: 2, pageSize: 10, total: 0 })
      );
    vi.stubGlobal('fetch', fetchMock);

    await expect(fetchMaterials({ page: 2, pageSize: 10 })).resolves.toEqual({
      items: [],
      page: 2,
      pageSize: 10,
      total: 0,
      totalPages: 1,
    });
    expect(fetchMock).toHaveBeenCalledWith(
      'https://api.example.test/api/v1/materials?page=2&pageSize=10',
      { signal: undefined }
    );
  });

  it('gets a material detail through the Gateway', async () => {
    vi.stubEnv('VITE_API_URL', 'https://api.example.test/api/v1');
    const fetchMock = vi.fn().mockResolvedValue(Response.json({ id: 'id/1' }));
    vi.stubGlobal('fetch', fetchMock);

    await fetchMaterial('id/1');

    expect(fetchMock).toHaveBeenCalledWith(
      'https://api.example.test/api/v1/materials/id%2F1',
      { signal: undefined }
    );
  });

  it('posts metadata and an optional file as multipart form data', async () => {
    vi.stubEnv('VITE_API_URL', 'https://api.example.test/api/v1');
    const fetchMock = vi.fn().mockResolvedValue(Response.json(createdResponse));
    vi.stubGlobal('fetch', fetchMock);

    const file = new File(['pdf'], 'notes.pdf', { type: 'application/pdf' });
    await createMaterial({
      title: 'Notes',
      year: '2026',
      type: 'DOCUMENT',
      subjectId: 'subject-1',
      professorId: 'prof-1',
      file,
    });

    const [, options] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(options.method).toBe('POST');
    expect(options.headers).toBeUndefined();
    expect(options.body).toBeInstanceOf(FormData);
    expect((options.body as FormData).get('file')).toBe(file);
    expect((options.body as FormData).get('professorId')).toBe('prof-1');
    expect((options.body as FormData).has('professor')).toBe(false);
  });

  it('returns downloaded content and rejects failed responses', async () => {
    vi.stubEnv('VITE_API_URL', 'https://api.example.test/api/v1');
    const file = new Blob(['file contents']);
    const successResponse = Response.json({});
    vi.spyOn(successResponse, 'blob').mockResolvedValue(file);
    const fetchMock = vi.fn().mockResolvedValue(successResponse);
    vi.stubGlobal('fetch', fetchMock);

    await expect(downloadMaterial('material-1')).resolves.toBe(successResponse);
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
  it.each<MaterialKind>([
    'DOCUMENT',
    'PRESENTATION',
    'EXAM',
    'SUMMARY',
    'LINK',
  ])(
    'supports the public creation type %s and caller authentication',
    async (type) => {
      vi.stubEnv('VITE_API_URL', 'https://api.example.test/api/v1/');
      const response = {
        ...createdResponse,
        data: { ...createdResponse.data, type },
      };
      const fetchMock = vi.fn().mockResolvedValue(Response.json(response));
      vi.stubGlobal('fetch', fetchMock);
      const signal = new AbortController().signal;
      const file = new File(['pdf'], 'notes.pdf', { type: 'application/pdf' });
      const result = await createMaterial(
        {
          title: 'Notes',
          year: '2026',
          type,
          subjectId: 'subject-1',
          ...(type === 'LINK'
            ? { externalLink: 'https://example.test/notes' }
            : { file }),
        },
        { accessToken: 'test-token', signal }
      );
      expect(result).toEqual(response);
      const [url, options] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect(url).toBe('https://api.example.test/api/v1/materials');
      expect(options.headers).toEqual({ Authorization: 'Bearer test-token' });
      expect(options.signal).toBe(signal);
      const body = options.body as FormData;
      expect(body.get('type')).toBe(type);
      expect(body.has('file')).toBe(type !== 'LINK');
      expect(body.get('externalLink')).toBe(
        type === 'LINK' ? 'https://example.test/notes' : null
      );
    }
  );

  it('does not fetch without the gateway configuration', async () => {
    vi.stubEnv('VITE_API_URL', '');
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    await expect(fetchMaterials()).rejects.toThrow('VITE_API_URL');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('preserves list mapping and cancellation from main', async () => {
    vi.stubEnv('VITE_API_URL', 'https://api.example.test/api/v1');
    const signal = new AbortController().signal;
    const fetchMock = vi.fn().mockResolvedValue(
      Response.json({
        items: [
          {
            id: 'm1',
            title: 'Notes',
            academicYear: 2026,
            materialType: 'EXAM',
            subjectId: 's1',
          },
        ],
        page: 1,
        pageSize: 20,
        total: 21,
      })
    );
    vi.stubGlobal('fetch', fetchMock);
    const result = await fetchMaterials({}, signal);
    expect(result.totalPages).toBe(2);
    expect(result.items[0]).toMatchObject({
      id: 'm1',
      title: 'Notes',
      year: 2026,
      type: 'EXAM',
    });
    expect(fetchMock.mock.calls[0][1]).toEqual({ signal });
    const aborted = new DOMException('Aborted', 'AbortError');
    fetchMock.mockRejectedValueOnce(aborted);
    await expect(fetchMaterials({}, signal)).rejects.toBe(aborted);
  });
});
