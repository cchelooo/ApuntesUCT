import type {
  CreateMaterialRequest,
  CreateMaterialResponse,
  ListMaterialsParams,
  MaterialDetailResponse,
  MaterialPage,
} from '../../domain/material/materialApi';

const DEFAULT_PAGE = 1;
const DEFAULT_PAGE_SIZE = 20;

function getMaterialsUrl(path = ''): string {
  const baseUrl = import.meta.env.VITE_API_URL;
  if (!baseUrl) {
    throw new Error('Falta configurar VITE_API_URL para acceder a la API.');
  }

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

export async function fetchMaterials({
  page = DEFAULT_PAGE,
  pageSize = DEFAULT_PAGE_SIZE,
}: ListMaterialsParams = {}): Promise<MaterialPage> {
  const params = new URLSearchParams({
    page: String(page),
    pageSize: String(pageSize),
  });
  const response = await fetch(getMaterialsUrl(`?${params.toString()}`));

  if (!response.ok) {
    await throwApiError(response);
  }

  return (await response.json()) as MaterialPage;
}

export async function fetchMaterial(
  materialId: string
): Promise<MaterialDetailResponse> {
  const response = await fetch(
    getMaterialsUrl(`/${encodeURIComponent(materialId)}`)
  );

  if (!response.ok) {
    await throwApiError(response);
  }

  return (await response.json()) as MaterialDetailResponse;
}

export async function createMaterial(
  material: CreateMaterialRequest
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
  if (material.professor !== undefined) {
    formData.append('professor', material.professor);
  }
  if (material.externalLink !== undefined) {
    formData.append('externalLink', material.externalLink);
  }
  if (material.file !== undefined) {
    formData.append('file', material.file);
  }

  const response = await fetch(getMaterialsUrl(), {
    method: 'POST',
    body: formData,
  });

  if (!response.ok) {
    await throwApiError(response);
  }

  return (await response.json()) as CreateMaterialResponse;
}

export async function downloadMaterial(materialId: string): Promise<Blob> {
  const response = await fetch(
    getMaterialsUrl(`/${encodeURIComponent(materialId)}/download`)
  );

  if (!response.ok) {
    await throwApiError(response);
  }

  return response.blob();
}
