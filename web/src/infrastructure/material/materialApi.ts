import type {
  CreateMaterialRequest,
  CreateMaterialResponse,
  MaterialDetailResponse,
  ListMaterialsParams,
} from '../../domain/material/materialApi';

import type { MaterialApiError } from './materialErrorHandler';
import { mapRawMaterialPage } from './mapMaterial';
import type { RawMaterialPage } from './rawMaterial';
import type { MaterialPage } from '../../domain/material/materialPage';

export interface MaterialRequestOptions {
  /** Passed by the caller; real authentication is still pending in backend. */
  accessToken?: string;
  signal?: AbortSignal;
}

function getMaterialsUrl(path = ''): string {
  const envUrl = import.meta.env.VITE_API_URL;
  if (envUrl === '') {
    throw new Error('VITE_API_URL is not configured');
  }
  const baseUrl = envUrl ?? 'http://localhost:3000/api/v1';

  return `${baseUrl.replace(/\/+$/, '')}/materials${path}`;
}

async function throwApiError(response: Response): Promise<never> {
  const body = await response.text();
  let message = body;

  if (body) {
    try {
      const parsed: unknown = JSON.parse(body);
      if (
        typeof parsed === 'object' &&
        parsed !== null &&
        'message' in parsed
      ) {
        const apiMessage = parsed.message;
        message = Array.isArray(apiMessage)
          ? apiMessage.join(', ')
          : String(apiMessage);
      }
    } catch {
      message = body;
    }
  }

  throw new Error(
    `Error al consultar Material Service (status ${response.status})${
      message ? `: ${message}` : ''
    }`
  );
}

export const DEFAULT_MATERIALS_PAGE_SIZE = 20;

export type MaterialsParams = ListMaterialsParams;
export class MaterialRequestError extends Error implements MaterialApiError {
  status?: number;
  isNetworkError?: boolean;

  constructor(
    message: string,
    init: { status?: number; isNetworkError?: boolean }
  ) {
    super(message);
    this.name = 'MaterialRequestError';
    this.status = init.status;
    this.isNetworkError = init.isNetworkError;
  }
}

function isRawMaterialPage(value: unknown): value is RawMaterialPage {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Partial<RawMaterialPage>;
  return (
    Array.isArray(candidate.items) &&
    typeof candidate.page === 'number' &&
    typeof candidate.pageSize === 'number' &&
    typeof candidate.total === 'number'
  );
}

export async function fetchMaterials(
  { page = 1, pageSize = DEFAULT_MATERIALS_PAGE_SIZE }: MaterialsParams = {},
  signal?: AbortSignal
): Promise<MaterialPage> {
  const params = new URLSearchParams({
    page: String(page),
    pageSize: String(pageSize),
  });

  const url = getMaterialsUrl(`?${params.toString()}`);
  let response: Response;
  try {
    response = await fetch(url, {
      signal,
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw error;
    }
    throw new MaterialRequestError('Fallo de red al obtener materiales', {
      isNetworkError: true,
    });
  }

  if (!response.ok) {
    throw new MaterialRequestError(
      `No se pudieron obtener los materiales (status ${response.status})`,
      { status: response.status }
    );
  }

  const body: unknown = await response.json();
  if (!isRawMaterialPage(body)) {
    throw new MaterialRequestError(
      'La respuesta de materiales no tiene el formato esperado',
      {}
    );
  }

  return mapRawMaterialPage(body);
}

export type MaterialTypeValue =
  'DOCUMENT' | 'PRESENTATION' | 'EXAM' | 'SUMMARY' | 'LINK';

export interface UploadMaterialInput {
  title: string;
  description?: string;
  year: string;
  type: MaterialTypeValue;
  subjectId: string;
  careerId?: string;
  professorId?: string;
  externalLink?: string;
  file?: File | Blob;
}

export async function uploadMaterial(
  input: UploadMaterialInput | FormData,
  signal?: AbortSignal
): Promise<unknown> {
  let body: FormData;
  if (input instanceof FormData) {
    body = input;
  } else {
    body = new FormData();
    body.append('title', input.title);
    if (input.description) body.append('description', input.description);
    body.append('year', input.year);
    body.append('type', input.type);
    body.append('subjectId', input.subjectId);
    if (input.careerId) body.append('careerId', input.careerId);
    if (input.professorId) body.append('professorId', input.professorId);
    if (input.externalLink) body.append('externalLink', input.externalLink);
    if (input.file) body.append('file', input.file);
  }

  let response: Response;
  try {
    response = await fetch(getMaterialsUrl(), {
      method: 'POST',
      body,
      signal,
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw error;
    }
    throw new MaterialRequestError('Fallo de red al subir el material', {
      isNetworkError: true,
    });
  }

  if (!response.ok) {
    let errorMessage = `No se pudo subir el material (status ${response.status})`;
    try {
      const data = await response.json();
      if (data && typeof data === 'object' && 'message' in data) {
        errorMessage = Array.isArray(data.message)
          ? data.message.join(', ')
          : String(data.message);
      }
    } catch {
      // Sin cuerpo JSON
    }

    throw new MaterialRequestError(errorMessage, {
      status: response.status,
    });
  }

  return response.json();
}

/** Provisional route: backend has not published the detail contract yet. */
export async function fetchMaterial(
  materialId: string,
  signal?: AbortSignal
): Promise<MaterialDetailResponse> {
  const response = await fetch(
    getMaterialsUrl(`/${encodeURIComponent(materialId)}`),
    { signal }
  );

  if (!response.ok) {
    await throwApiError(response);
  }

  return (await response.json()) as MaterialDetailResponse;
}

export async function createMaterial(
  material: CreateMaterialRequest,
  options: MaterialRequestOptions = {}
): Promise<CreateMaterialResponse> {
  const formData = new FormData();
  formData.append('title', material.title);
  formData.append('year', material.year);
  formData.append('type', material.type);
  formData.append('subjectId', material.subjectId);

  if (material.description !== undefined) {
    formData.append('description', material.description);
  }
  if (material.careerId !== undefined) {
    formData.append('careerId', material.careerId);
  }
  if (material.professorId !== undefined) {
    formData.append('professorId', material.professorId);
  }
  if (material.externalLink !== undefined) {
    formData.append('externalLink', material.externalLink);
  }
  if (material.file !== undefined) {
    formData.append('file', material.file);
  }

  const response = await fetch(getMaterialsUrl(), {
    method: 'POST',
    signal: options.signal,
    headers: options.accessToken
      ? { Authorization: `Bearer ${options.accessToken}` }
      : undefined,
    body: formData,
  });

  if (!response.ok) {
    await throwApiError(response);
  }

  return (await response.json()) as CreateMaterialResponse;
}

/** Provisional route: return the response until backend defines the download format. */
export async function downloadMaterial(materialId: string): Promise<Response> {
  const response = await fetch(
    getMaterialsUrl(`/${encodeURIComponent(materialId)}/download`)
  );

  if (!response.ok) {
    await throwApiError(response);
  }

  return response;
}
