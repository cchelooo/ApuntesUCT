import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import {
  uploadMaterial,
  createMaterial,
  fetchMaterials,
  MaterialRequestError,
  DEFAULT_MATERIALS_PAGE_SIZE,
} from './materialApi';

describe('materialApi - uploadMaterial / createMaterial', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn());
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('envía los metadatos y el archivo correctamente mediante POST multipart', async () => {
    const mockFile = new File(['contenido de prueba'], 'apunte.pdf', {
      type: 'application/pdf',
    });

    const mockResponseData = {
      status: 'success',
      message: 'Material registrado exitosamente en estado PENDING_REVIEW.',
      data: {
        id: 'mat-123',
        title: 'Apunte de Redes',
        description: 'Guía de subnetting',
        year: '2026',
        type: 'DOCUMENT',
        status: 'PENDING_REVIEW',
        subjectId: 'RED-101',
        careerId: 'INF-01',
        professorId: 'PROF-99',
        externalLink: 'https://drive.google.com/apunte',
      },
    };

    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(JSON.stringify(mockResponseData), {
        status: 201,
        headers: { 'Content-Type': 'application/json' },
      })
    );

    const payload = {
      title: 'Apunte de Redes',
      description: 'Guía de subnetting',
      year: '2026',
      type: 'DOCUMENT',
      subjectId: 'RED-101',
      careerId: 'INF-01',
      professorId: 'PROF-99',
      externalLink: 'https://drive.google.com/apunte',
      file: mockFile,
    };

    const result = await uploadMaterial(payload);

    expect(result).toEqual(mockResponseData);
    expect(fetch).toHaveBeenCalledTimes(1);

    const [calledUrl, options] = vi.mocked(fetch).mock.calls[0];
    expect(calledUrl).toContain('/materials');
    expect(options?.method).toBe('POST');
    expect(options?.body).toBeInstanceOf(FormData);

    const sentFormData = options?.body as FormData;
    expect(sentFormData.get('title')).toBe('Apunte de Redes');
    expect(sentFormData.get('description')).toBe('Guía de subnetting');
    expect(sentFormData.get('year')).toBe('2026');
    expect(sentFormData.get('type')).toBe('DOCUMENT');
    expect(sentFormData.get('subjectId')).toBe('RED-101');
    expect(sentFormData.get('careerId')).toBe('INF-01');
    expect(sentFormData.get('professorId')).toBe('PROF-99');
    expect(sentFormData.get('externalLink')).toBe(
      'https://drive.google.com/apunte'
    );
    expect(sentFormData.get('file')).toBe(mockFile);
  });

  it('permite enviar directamente un objeto FormData personalizado', async () => {
    const formData = new FormData();
    formData.append('title', 'Guía de Física');
    formData.append('year', '2025');
    formData.append('type', 'DOCUMENT');
    formData.append('subjectId', 'FIS-201');

    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(
        JSON.stringify({ status: 'success', data: { id: 'fis-1' } }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }
      )
    );

    const result = await uploadMaterial(formData);
    expect(result.status).toBe('success');

    const [, options] = vi.mocked(fetch).mock.calls[0];
    expect(options?.body).toBe(formData);
  });

  it('maneja el código de error HTTP 413 (Payload Too Large) lanzando MaterialRequestError', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          statusCode: 413,
          message: 'El archivo excede el tamaño máximo permitido de 15 MB.',
        }),
        { status: 413 }
      )
    );

    const payload = {
      title: 'Libro muy pesado',
      year: '2026',
      type: 'DOCUMENT',
      subjectId: 'MAT-101',
      file: new File(['x'.repeat(100)], 'pesado.pdf'),
    };

    let caughtError: unknown;
    try {
      await uploadMaterial(payload);
    } catch (err) {
      caughtError = err;
    }

    expect(caughtError).toBeInstanceOf(MaterialRequestError);
    const apiError = caughtError as MaterialRequestError;
    expect(apiError.status).toBe(413);
    expect(apiError.message).toContain('413');
  });

  it('maneja el código de error HTTP 415 (Unsupported Media Type) lanzando MaterialRequestError', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(
        JSON.stringify({
          statusCode: 415,
          message: 'Tipo de archivo no admitido.',
        }),
        { status: 415 }
      )
    );

    const payload = {
      title: 'Archivo no permitido',
      year: '2026',
      type: 'DOCUMENT',
      subjectId: 'MAT-101',
      file: new File(['ejecutable'], 'programa.exe', {
        type: 'application/x-msdownload',
      }),
    };

    let caughtError: unknown;
    try {
      await uploadMaterial(payload);
    } catch (err) {
      caughtError = err;
    }

    expect(caughtError).toBeInstanceOf(MaterialRequestError);
    const apiError = caughtError as MaterialRequestError;
    expect(apiError.status).toBe(415);
    expect(apiError.message).toContain('415');
  });

  it('maneja errores HTTP 400 y 401 lanzando MaterialRequestError con el status correspondiente', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(JSON.stringify({ message: 'Datos incompletos' }), {
        status: 400,
      })
    );

    await expect(
      uploadMaterial({
        title: '',
        year: '2026',
        type: 'DOCUMENT',
        subjectId: 'MAT-101',
      })
    ).rejects.toMatchObject({
      status: 400,
      name: 'MaterialRequestError',
    });

    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(JSON.stringify({ message: 'No autenticado' }), {
        status: 401,
      })
    );

    await expect(
      uploadMaterial({
        title: 'Título',
        year: '2026',
        type: 'DOCUMENT',
        subjectId: 'MAT-101',
      })
    ).rejects.toMatchObject({
      status: 401,
      name: 'MaterialRequestError',
    });
  });

  it('maneja fallos de red marcando isNetworkError como true', async () => {
    vi.mocked(fetch).mockRejectedValueOnce(new TypeError('Failed to fetch'));

    let caughtError: unknown;
    try {
      await uploadMaterial({
        title: 'Título',
        year: '2026',
        type: 'DOCUMENT',
        subjectId: 'MAT-101',
      });
    } catch (err) {
      caughtError = err;
    }

    expect(caughtError).toBeInstanceOf(MaterialRequestError);
    const apiError = caughtError as MaterialRequestError;
    expect(apiError.isNetworkError).toBe(true);
    expect(apiError.message).toBe('Fallo de red al subir el material');
  });

  it('propaga AbortError sin convertirlo en error genérico de red cuando se cancela', async () => {
    const abortError = new DOMException(
      'The user aborted a request.',
      'AbortError'
    );
    vi.mocked(fetch).mockRejectedValueOnce(abortError);

    const controller = new AbortController();
    await expect(
      uploadMaterial(
        {
          title: 'Título',
          year: '2026',
          type: 'DOCUMENT',
          subjectId: 'MAT-101',
        },
        controller.signal
      )
    ).rejects.toThrow(abortError);
  });

  it('el alias createMaterial funciona de forma idéntica a uploadMaterial', () => {
    expect(createMaterial).toBe(uploadMaterial);
  });
});

describe('materialApi - fetchMaterials', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn());
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('solicita materiales con parámetros por defecto', async () => {
    const rawPage = {
      items: [
        {
          id: '1',
          title: 'Álgebra Lineal',
          academicYear: 2024,
          materialType: 'DOCUMENT',
          subjectId: 'SUB-1',
          professorId: 'PROF-1',
        },
      ],
      page: 1,
      pageSize: DEFAULT_MATERIALS_PAGE_SIZE,
      total: 1,
    };

    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(JSON.stringify(rawPage), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    );

    const result = await fetchMaterials();
    expect(result.items).toHaveLength(1);
    expect(result.page).toBe(1);
    expect(result.total).toBe(1);

    const [calledUrl] = vi.mocked(fetch).mock.calls[0];
    expect(calledUrl).toContain(
      `page=1&pageSize=${DEFAULT_MATERIALS_PAGE_SIZE}`
    );
  });

  it('maneja error cuando la respuesta no tiene el formato esperado', async () => {
    vi.mocked(fetch).mockResolvedValueOnce(
      new Response(JSON.stringify({ inesperado: true }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    );

    await expect(fetchMaterials()).rejects.toThrow(
      'La respuesta de materiales no tiene el formato esperado'
    );
  });

  it('maneja fallos de red en fetchMaterials con isNetworkError', async () => {
    vi.mocked(fetch).mockRejectedValueOnce(new TypeError('Failed to fetch'));

    await expect(fetchMaterials()).rejects.toMatchObject({
      isNetworkError: true,
      message: 'Fallo de red al obtener materiales',
    });
  });
});
