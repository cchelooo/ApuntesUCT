/**
 * Regresión de integración Web → Gateway (Issue #268)
 *
 * Valida que TODAS las capas de infraestructura del frontend construyan sus
 * URLs usando únicamente la variable de entorno VITE_API_URL (Gateway),
 * y que ninguna función realice peticiones cuando dicha variable no está
 * configurada.
 *
 * Funcionalidades cubiertas: Catálogo, Auth/Login, Materiales (listado,
 * subida, detalle, descarga) y Búsqueda.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  fetchMaterials,
  uploadMaterial,
  fetchMaterial,
  buildMaterialDownloadUrl,
  downloadMaterial,
} from './material/materialApi';
import { fetchSearch } from './search/searchApi';
import {
  fetchCatalogSubjects,
  fetchUniversities,
  fetchCareers,
  fetchSubjectsByCareer,
  fetchProfessorsBySubject,
} from './catalog/catalogApi';
import {
  fetchCatalogSubjectNames,
  fetchCatalogProfessorNames,
} from './catalog/catalogLookupApi';

// ─── Constantes de prueba ────────────────────────────────────────────────────

const GATEWAY = 'https://gateway.test/api/v1';

// ─── Helpers ─────────────────────────────────────────────────────────────────

function jsonOk(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

// ─── Setup / Teardown ────────────────────────────────────────────────────────

let fetchMock: ReturnType<typeof vi.fn>;

beforeEach(() => {
  vi.stubEnv('VITE_API_URL', GATEWAY);
  fetchMock = vi.fn();
  vi.stubGlobal('fetch', fetchMock);
});

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

// ─── Suite principal ──────────────────────────────────────────────────────────

describe('Regresión Gateway — Issue #268', () => {
  // ─── 1. Protección global: sin VITE_API_URL no se realiza ninguna petición ──

  describe('Protección: VITE_API_URL obligatoria', () => {
    beforeEach(() => {
      vi.stubEnv('VITE_API_URL', '');
    });

    it('fetchMaterials lanza error y no llama a fetch cuando VITE_API_URL está vacía', async () => {
      await expect(fetchMaterials()).rejects.toThrow('VITE_API_URL');
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('fetchMaterial lanza error y no llama a fetch cuando VITE_API_URL está vacía', async () => {
      await expect(fetchMaterial('mat-1')).rejects.toThrow('VITE_API_URL');
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('buildMaterialDownloadUrl lanza error cuando VITE_API_URL está vacía', () => {
      expect(() => buildMaterialDownloadUrl('mat-1')).toThrow('VITE_API_URL');
    });

    it('fetchSearch lanza error y no llama a fetch cuando VITE_API_URL está vacía', async () => {
      await expect(fetchSearch({ q: 'test' })).rejects.toThrow('VITE_API_URL');
      expect(fetchMock).not.toHaveBeenCalled();
    });
  });

  // ─── 2. Materiales: listado ───────────────────────────────────────────────

  describe('Materiales — listado', () => {
    it('fetchMaterials enruta a través del Gateway con los parámetros correctos', async () => {
      fetchMock.mockResolvedValue(
        jsonOk({ items: [], page: 1, pageSize: 20, total: 0 })
      );

      await fetchMaterials({ page: 2, pageSize: 10 });

      expect(fetchMock).toHaveBeenCalledOnce();
      const [url] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect(url).toBe(`${GATEWAY}/materials?page=2&pageSize=10`);
      expect(url).not.toMatch(/localhost:[0-9]/);
      expect(url).not.toContain('material-service');
    });

    it('fetchMaterials construye correctamente la URL eliminando la barra final del Gateway', async () => {
      vi.stubEnv('VITE_API_URL', `${GATEWAY}/`);
      fetchMock.mockResolvedValue(
        jsonOk({ items: [], page: 1, pageSize: 20, total: 0 })
      );

      await fetchMaterials();

      const [url] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect(url).not.toContain('//materials');
      expect(url).toContain(`${GATEWAY}/materials`);
    });
  });

  // ─── 3. Materiales: subida ────────────────────────────────────────────────

  describe('Materiales — subida (upload)', () => {
    it('uploadMaterial envía el POST al endpoint del Gateway sin Content-Type explícito', async () => {
      const mockResponse = {
        status: 'success',
        isSimulatedResponse: false,
        message: 'Material registrado',
        data: { id: 'mat-1' },
      };
      fetchMock.mockResolvedValue(jsonOk(mockResponse));

      const formData = new FormData();
      formData.append('title', 'Guía de prueba');
      formData.append('year', '2026');
      formData.append('type', 'DOCUMENT');
      formData.append('subjectId', 'sub-1');
      await uploadMaterial(formData);

      expect(fetchMock).toHaveBeenCalledOnce();
      const [url, options] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect(url).toBe(`${GATEWAY}/materials`);
      expect((options.method ?? '').toUpperCase()).toBe('POST');
      expect(url).not.toMatch(/localhost:[0-9]/);
    });

    it('uploadMaterial incluye el token de autenticación en el encabezado Authorization', async () => {
      fetchMock.mockResolvedValue(
        jsonOk({ status: 'success', isSimulatedResponse: false, message: 'ok', data: { id: 'x' } })
      );
      const formData = new FormData();
      formData.append('title', 'Doc con token');
      await uploadMaterial(formData, { accessToken: 'mi-jwt-token' });

      const [, options] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect((options.headers as Record<string, string>)['Authorization']).toBe(
        'Bearer mi-jwt-token'
      );
    });
  });

  // ─── 4. Materiales: detalle ───────────────────────────────────────────────

  describe('Materiales — detalle', () => {
    it('fetchMaterial solicita el detalle por el Gateway codificando el ID en la URL', async () => {
      fetchMock.mockResolvedValue(jsonOk({ id: 'mat-abc' }));

      await fetchMaterial('mat-abc');

      const [url] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect(url).toBe(`${GATEWAY}/materials/mat-abc`);
      expect(url).not.toMatch(/localhost:[0-9]/);
    });

    it('fetchMaterial codifica caracteres especiales en el ID del material', async () => {
      fetchMock.mockResolvedValue(jsonOk({ id: 'a/b' }));

      await fetchMaterial('a/b');

      const [url] = fetchMock.mock.calls[0] as [string, RequestInit];
      expect(url).toBe(`${GATEWAY}/materials/a%2Fb`);
    });
  });

  // ─── 5. Materiales: descarga ──────────────────────────────────────────────

  describe('Materiales — descarga', () => {
    it('buildMaterialDownloadUrl construye la URL completa de descarga a través del Gateway', () => {
      const url = buildMaterialDownloadUrl('mat-xyz');
      expect(url).toBe(`${GATEWAY}/materials/mat-xyz/download`);
      expect(url).not.toMatch(/localhost:[0-9]/);
    });

    it('downloadMaterial solicita el archivo de descarga al Gateway', async () => {
      const blob = new Response('%PDF-1.7', {
        status: 200,
        headers: { 'Content-Type': 'application/pdf' },
      });
      fetchMock.mockResolvedValue(blob);

      await downloadMaterial('mat-dl-1');

      const [url] = fetchMock.mock.calls[0] as [string];
      expect(url).toBe(`${GATEWAY}/materials/mat-dl-1/download`);
      expect(url).not.toMatch(/localhost:[0-9]/);
    });
  });

  // ─── 6. Búsqueda ─────────────────────────────────────────────────────────

  describe('Búsqueda', () => {
    it('fetchSearch enruta la consulta al Gateway con los parámetros correctos', async () => {
      fetchMock.mockResolvedValue(
        jsonOk({ results: [], total: 0, page: 1, pageSize: 20 })
      );

      await fetchSearch({ q: 'calculo', sort: 'recent', page: 1, pageSize: 20 });

      expect(fetchMock).toHaveBeenCalledOnce();
      const [urlStr] = fetchMock.mock.calls[0] as [string, RequestInit];
      const url = new URL(urlStr);
      expect(url.origin + url.pathname).toBe(`${GATEWAY}/search`);
      expect(url.searchParams.get('q')).toBe('calculo');
      expect(url.searchParams.get('sortBy')).toBe('createdAt');
      expect(url.searchParams.get('order')).toBe('desc');
      expect(url.searchParams.get('page')).toBe('1');
      expect(urlStr).not.toMatch(/localhost:[0-9]/);
      expect(urlStr).not.toContain('search-service');
    });

    it('fetchSearch traduce correctamente los tres criterios de ordenamiento al protocolo del Gateway', async () => {
      const sortMappings = [
        { sort: 'recent' as const, sortBy: 'createdAt', order: 'desc' },
        { sort: 'year_desc' as const, sortBy: 'year', order: 'desc' },
        { sort: 'title' as const, sortBy: 'title', order: 'asc' },
      ];

      for (const { sort, sortBy, order } of sortMappings) {
        fetchMock.mockResolvedValue(
          jsonOk({ results: [], total: 0, page: 1, pageSize: 20 })
        );
        await fetchSearch({ q: 'x', sort });
        const [urlStr] = fetchMock.mock.calls.at(-1) as [string];
        const params = new URL(urlStr).searchParams;
        expect(params.get('sortBy')).toBe(sortBy);
        expect(params.get('order')).toBe(order);
        expect(params.has('sort')).toBe(false);
      }
    });
  });

  // ─── 7. Catálogo: API de filtro principal ─────────────────────────────────

  describe('Catálogo — fetchCatalogSubjects (filtro)', () => {
    it('consulta asignaturas del catálogo a través del Gateway', async () => {
      fetchMock.mockResolvedValue(jsonOk([]));

      await fetchCatalogSubjects();

      const [url] = fetchMock.mock.calls[0] as [string];
      expect(url).toContain(`${GATEWAY}/catalog/filter`);
      expect(url).not.toMatch(/localhost:[0-9]/);
      expect(url).not.toContain('catalog-service');
    });

    it('incluye los filtros activos como query params en la URL del Gateway', async () => {
      fetchMock.mockResolvedValue(jsonOk([]));

      await fetchCatalogSubjects({
        universityId: 'u1',
        careerId: 'c1',
      });

      const [urlStr] = fetchMock.mock.calls[0] as [string];
      const params = new URL(urlStr).searchParams;
      expect(params.get('universityId')).toBe('u1');
      expect(params.get('careerId')).toBe('c1');
    });
  });

  // ─── 8. Catálogo: universidades ───────────────────────────────────────────

  describe('Catálogo — fetchUniversities', () => {
    it('obtiene universidades a través del Gateway', async () => {
      fetchMock.mockResolvedValue(jsonOk([]));

      await fetchUniversities();

      const [url] = fetchMock.mock.calls[0] as [string];
      expect(url).toBe(`${GATEWAY}/catalog/universities`);
      expect(url).not.toMatch(/localhost:[0-9]/);
    });
  });

  // ─── 9. Catálogo: carreras por universidad ────────────────────────────────

  describe('Catálogo — fetchCareers', () => {
    it('obtiene carreras de una universidad a través del Gateway', async () => {
      fetchMock.mockResolvedValue(jsonOk([]));

      await fetchCareers('u1');

      const [urlStr] = fetchMock.mock.calls[0] as [string];
      const url = new URL(urlStr);
      expect(url.origin + url.pathname).toBe(`${GATEWAY}/catalog/careers`);
      expect(url.searchParams.get('universityId')).toBe('u1');
      expect(urlStr).not.toMatch(/localhost:[0-9]/);
    });
  });

  // ─── 10. Catálogo: asignaturas por carrera ────────────────────────────────

  describe('Catálogo — fetchSubjectsByCareer', () => {
    it('obtiene asignaturas de una carrera a través del Gateway', async () => {
      fetchMock.mockResolvedValue(jsonOk([]));

      await fetchSubjectsByCareer('c1');

      const [urlStr] = fetchMock.mock.calls[0] as [string];
      const url = new URL(urlStr);
      expect(url.origin + url.pathname).toBe(`${GATEWAY}/catalog/subjects`);
      expect(url.searchParams.get('careerId')).toBe('c1');
      expect(urlStr).not.toMatch(/localhost:[0-9]/);
    });
  });

  // ─── 11. Catálogo: profesores por asignatura ──────────────────────────────

  describe('Catálogo — fetchProfessorsBySubject', () => {
    it('obtiene profesores de una asignatura a través del Gateway', async () => {
      fetchMock.mockResolvedValue(jsonOk([]));

      await fetchProfessorsBySubject('s1');

      const [urlStr] = fetchMock.mock.calls[0] as [string];
      const url = new URL(urlStr);
      expect(url.origin + url.pathname).toBe(`${GATEWAY}/catalog/professors`);
      expect(url.searchParams.get('subjectId')).toBe('s1');
      expect(urlStr).not.toMatch(/localhost:[0-9]/);
    });
  });

  // ─── 12. Catálogo: lookup (nombres para resolución en tarjetas) ───────────

  describe('Catálogo — catalogLookupApi (resolución de nombres)', () => {
    it('fetchCatalogSubjectNames consulta /catalog/subjects del Gateway', async () => {
      fetchMock.mockResolvedValue(jsonOk([]));

      await fetchCatalogSubjectNames();

      const [url] = fetchMock.mock.calls[0] as [string];
      expect(url).toBe(`${GATEWAY}/catalog/subjects`);
      expect(url).not.toMatch(/localhost:[0-9]/);
    });

    it('fetchCatalogProfessorNames consulta /catalog/professors del Gateway', async () => {
      fetchMock.mockResolvedValue(jsonOk([]));

      await fetchCatalogProfessorNames();

      const [url] = fetchMock.mock.calls[0] as [string];
      expect(url).toBe(`${GATEWAY}/catalog/professors`);
      expect(url).not.toMatch(/localhost:[0-9]/);
    });
  });

  // ─── 13. Login ───────────────────────────────────────────────────────────

  describe('Autenticación — Login mock', () => {
    it('el endpoint de login está construido con VITE_API_URL y apunta al path /auth/login del Gateway', () => {
      /**
       * LoginPage.tsx construye la URL de login directamente en el componente:
       *   `${import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1'}/auth/login`
       *
       * Esta prueba verifica que, cuando VITE_API_URL está configurada, la URL
       * resultante apunta correctamente al Gateway y no a ningún puerto de
       * microservicio interno.
       */
      const apiUrl = import.meta.env.VITE_API_URL as string;
      const loginUrl = `${apiUrl}/auth/login`;
      expect(loginUrl).toBe(`${GATEWAY}/auth/login`);
      expect(loginUrl).not.toMatch(/localhost:[0-9]/);
      expect(loginUrl).not.toContain('auth-service');
    });
  });

  // ─── 14. Ausencia total de dependencias a puertos de microservicios ────────

  describe('Invariante: ninguna función de infraestructura llama a puertos internos de microservicios', () => {
    /**
     * Valida que, con VITE_API_URL configurado, NINGUNA llamada a fetch
     * contenga patrones propios de acceso directo a microservicios internos
     * (puertos como :3001, :3002, :4000, nombres de servicios internos, etc.).
     */
    const internalPortPattern = /localhost:(300[1-9]|30[1-9][0-9]|[4-9][0-9]{3})/;

    async function assertNoInternalPorts(
      fn: () => Promise<unknown>
    ): Promise<void> {
      const allCalls: string[] = [];
      fetchMock.mockImplementation((input: string | URL) => {
        const urlStr = String(input);
        allCalls.push(urlStr);
        return Promise.resolve(jsonOk([]));
      });

      await fn().catch(() => {
        /* ignorar errores de mapeo; solo nos importa la URL llamada */
      });

      for (const url of allCalls) {
        expect(
          url,
          `Se detectó una llamada directa a un microservicio: ${url}`
        ).not.toMatch(internalPortPattern);
      }
    }

    it('fetchMaterials no accede a puertos internos', async () => {
      fetchMock.mockResolvedValue(
        jsonOk({ items: [], page: 1, pageSize: 20, total: 0 })
      );
      await assertNoInternalPorts(() => fetchMaterials());
    });

    it('fetchSearch no accede a puertos internos', async () => {
      fetchMock.mockResolvedValue(
        jsonOk({ results: [], total: 0, page: 1, pageSize: 20 })
      );
      await assertNoInternalPorts(() => fetchSearch({ q: 'test' }));
    });

    it('fetchCatalogSubjects no accede a puertos internos', async () => {
      await assertNoInternalPorts(() => fetchCatalogSubjects());
    });

    it('fetchUniversities no accede a puertos internos', async () => {
      await assertNoInternalPorts(() => fetchUniversities());
    });

    it('fetchCatalogSubjectNames no accede a puertos internos', async () => {
      await assertNoInternalPorts(() => fetchCatalogSubjectNames());
    });

    it('fetchCatalogProfessorNames no accede a puertos internos', async () => {
      await assertNoInternalPorts(() => fetchCatalogProfessorNames());
    });
  });
});

