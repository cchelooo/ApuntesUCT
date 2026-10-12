import { useQuery } from '@tanstack/react-query';
import {
  fetchMaterialDetail,
  MaterialRequestError,
} from '../../infrastructure/material/materialApi';

export function isMaterialNotFound(error: unknown): boolean {
  return (
    error instanceof MaterialRequestError &&
    (error.status === 404 || error.status === 400)
  );
}

export function useMaterialDetailQuery(materialId?: string) {
  return useQuery({
    queryKey: ['materials', 'detail', materialId],
    queryFn: ({ signal }) => fetchMaterialDetail(materialId!, signal),
    enabled: !!materialId,
    retry: (failureCount, error) =>
      !isMaterialNotFound(error) && failureCount < 2,
  });
}
