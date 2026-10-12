import type { MaterialApiError } from './materialErrorHandler';
import { mapRawMaterialPage } from './mapMaterial';
import type { RawMaterialPage } from './rawMaterial';
import type { MaterialPage } from '../../domain/material/materialPage';

const baseUrl = import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1';

export const DEFAULT_MATERIALS_PAGE_SIZE = 20;

export interface MaterialsParams {
  page?: number;
  pageSize?: number;
}
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

  let response: Response;
  try {
    response = await fetch(`${baseUrl}/materials?${params.toString()}`, {
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

export interface UploadMaterialPayload {
  title: string;
  description?: string;
  year: string | number;
  type: string;
  subjectId: string;
  careerId?: string;
  professorId?: string;
  externalLink?: string;
  file?: File | Blob | null;
}

export interface UploadMaterialResponseData {
  id: string;
  title: string;
  description?: string | null;
  year: string;
  type: string;
  status: string;
  subjectId: string;
  careerId?: string | null;
  professorId?: string | null;
  universityId?: string | null;
  fileUrl?: string | null;
  fileSize?: number | null;
  mimeType?: string | null;
  externalLink?: string | null;
  createdAt?: string;
}

export interface UploadMaterialResponse {
  status: string;
  isSimulatedResponse?: boolean;
  message: string;
  data: UploadMaterialResponseData;
}

export async function uploadMaterial(
  payload: UploadMaterialPayload | FormData,
  signal?: AbortSignal
): Promise<UploadMaterialResponse> {
  let body: FormData;
  if (payload instanceof FormData) {
    body = payload;
  } else {
    body = new FormData();
    body.append('title', payload.title.trim());
    if (payload.description) {
      body.append('description', payload.description.trim());
    }
    body.append('year', String(payload.year).trim());
    body.append('type', payload.type);
    body.append('subjectId', payload.subjectId.trim());
    if (payload.careerId) {
      body.append('careerId', payload.careerId.trim());
    }
    if (payload.professorId) {
      body.append('professorId', payload.professorId.trim());
    }
    if (payload.externalLink) {
      body.append('externalLink', payload.externalLink.trim());
    }
    if (payload.file) {
      body.append('file', payload.file);
    }
  }

  let response: Response;
  try {
    response = await fetch(`${baseUrl}/materials`, {
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
    throw new MaterialRequestError(
      `No se pudo subir el material (status ${response.status})`,
      { status: response.status }
    );
  }

  return response.json();
}

export const createMaterial = uploadMaterial;
