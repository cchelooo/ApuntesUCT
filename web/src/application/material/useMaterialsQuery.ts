import { keepPreviousData, useQuery } from '@tanstack/react-query';
import {
  fetchMaterials,
  type MaterialsParams,
} from '../../infrastructure/material/materialApi';

export function useMaterialsQuery(params: MaterialsParams = {}) {
  return useQuery({
    queryKey: ['materials', 'list', params],
    queryFn: ({ signal }) => fetchMaterials(params, signal),
    placeholderData: keepPreviousData,
  });
}
