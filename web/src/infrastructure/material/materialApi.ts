import type { MaterialApiError } from './materialErrorHandler';
import { mapRawMaterialPage } from './mapMaterial';
import type { RawMaterialDetail, RawMaterialPage } from './rawMaterial';
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

function isRawMaterialDetail(value: unknown): value is RawMaterialDetail {
  if (typeof value !== 'object' || value === null) return false;
  const id = (value as { id?: unknown }).id;
  return typeof id === 'string' && id.length > 0;
}

async function request(url: string, signal?: AbortSignal): Promise<Response> {
  try {
    return await fetch(url, { signal });
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw error;
    }
    throw new MaterialRequestError('Fallo de red al consultar materiales', {
      isNetworkError: true,
    });
  }
}

export async function fetchMaterials(
  { page = 1, pageSize = DEFAULT_MATERIALS_PAGE_SIZE }: MaterialsParams = {},
  signal?: AbortSignal
): Promise<MaterialPage> {
  const params = new URLSearchParams({
    page: String(page),
    pageSize: String(pageSize),
  });

  const response = await request(
    `${baseUrl}/materials?${params.toString()}`,
    signal
  );

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

export async function fetchMaterialDetail(
  id: string,
  signal?: AbortSignal
): Promise<RawMaterialDetail> {
  const response = await request(
    `${baseUrl}/materials/${encodeURIComponent(id)}`,
    signal
  );

  if (!response.ok) {
    throw new MaterialRequestError(
      `No se pudo obtener el material (status ${response.status})`,
      { status: response.status }
    );
  }

  const body: unknown = await response.json();
  if (!isRawMaterialDetail(body)) {
    throw new MaterialRequestError(
      'La respuesta del material no tiene el formato esperado',
      {}
    );
  }
  return body;
}

export function buildMaterialDownloadUrl(id: string): string {
  return `${baseUrl}/materials/${encodeURIComponent(id)}/download`;
}
