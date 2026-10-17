import { useMemo } from 'react';
import { useParams } from 'react-router-dom';
import { useCatalogNamesQuery } from '../../application/catalog/useCatalogNamesQuery';
import { useMaterialQuery } from '../../application/material/useMaterialQueries';
import type { MaterialViewStatus } from '../../domain/material/material';
import { mapMaterialDetail } from '../../infrastructure/material/mapMaterialDetail';
import { isMaterialNotFound } from '../../infrastructure/material/materialApi';
import { MaterialDetailPage } from './MaterialDetailPage';

export function MaterialDetailRoute() {
  const { materialId } = useParams<{ materialId: string }>();
  const { data, isPending, isError, error } = useMaterialQuery(
    materialId ?? ''
  );

  const { data: names } = useCatalogNamesQuery();

  const material = useMemo(
    () => (data ? mapMaterialDetail(data, names) : null),
    [data, names]
  );

  let status: MaterialViewStatus = 'ready';
  if (!materialId) status = 'not-found';
  else if (isError)
    status = isMaterialNotFound(error) ? 'not-found' : 'unavailable';
  else if (isPending) status = 'loading';

  return (
    <MaterialDetailPage
      materialId={materialId}
      material={material}
      status={status}
    />
  );
}
