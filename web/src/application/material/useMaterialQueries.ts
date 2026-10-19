import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type {
  CreateMaterialRequest,
  ListMaterialsParams,
} from '../../domain/material/materialApi';
import {
  createMaterial,
  downloadMaterial,
  fetchMaterial,
  isMaterialNotFound,
} from '../../infrastructure/material/materialApi';

export const materialQueryKeys = {
  all: ['materials'] as const,
  lists: () => [...materialQueryKeys.all, 'list'] as const,
  list: (params: ListMaterialsParams = {}) =>
    [...materialQueryKeys.lists(), params] as const,
  details: () => [...materialQueryKeys.all, 'detail'] as const,
  detail: (id: string) => [...materialQueryKeys.details(), id] as const,
};

export { useMaterialsQuery } from './useMaterialsQuery';

export const MATERIAL_DETAIL_RETRY_DELAY_MS = 500;

export function useMaterialQuery(materialId: string) {
  return useQuery({
    queryKey: materialQueryKeys.detail(materialId),
    queryFn: ({ signal }) => fetchMaterial(materialId, signal),
    enabled: Boolean(materialId),
    retry: (failureCount, error) =>
      !isMaterialNotFound(error) && failureCount < 1,
    retryDelay: MATERIAL_DETAIL_RETRY_DELAY_MS,
  });
}

export function useCreateMaterialMutation(accessToken?: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (material: CreateMaterialRequest) =>
      createMaterial(material, { accessToken }),
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
