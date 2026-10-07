import {
  useMutation,
  useQuery,
  useQueryClient,
} from '@tanstack/react-query';
import type {
  CreateMaterialRequest,
  ListMaterialsParams,
} from '../../domain/material/materialApi';
import {
  createMaterial,
  downloadMaterial,
  fetchMaterial,
  fetchMaterials,
} from '../../infrastructure/material/materialApi';

export const materialQueryKeys = {
  all: ['materials'] as const,
  lists: () => [...materialQueryKeys.all, 'list'] as const,
  list: (params: ListMaterialsParams = {}) =>
    [...materialQueryKeys.lists(), params] as const,
  details: () => [...materialQueryKeys.all, 'detail'] as const,
  detail: (id: string) => [...materialQueryKeys.details(), id] as const,
};

export function useMaterialsQuery(params: ListMaterialsParams = {}) {
  return useQuery({
    queryKey: materialQueryKeys.list(params),
    queryFn: () => fetchMaterials(params),
  });
}

export function useMaterialQuery(materialId: string) {
  return useQuery({
    queryKey: materialQueryKeys.detail(materialId),
    queryFn: () => fetchMaterial(materialId),
    enabled: Boolean(materialId),
  });
}

export function useCreateMaterialMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (material: CreateMaterialRequest) => createMaterial(material),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: materialQueryKeys.all });
    },
  });
}

export function useDownloadMaterialMutation() {
  return useMutation({
    mutationFn: (materialId: string) => downloadMaterial(materialId),
  });
}
