import { useState } from 'react';
import { useMaterialsQuery } from '../../../application/material/useMaterialsQuery';
import { DEFAULT_MATERIALS_PAGE_SIZE } from '../../../infrastructure/material/materialApi';
import { mapMaterialError } from '../../../infrastructure/material/materialErrorHandler';
import { Alert } from '../Alert';
import { Button } from '../Button';
import { MaterialList } from './MaterialList';
import { MaterialPagination } from './MaterialPagination';

interface MaterialListSectionProps {
  pageSize?: number;
}

export function MaterialListSection({
  pageSize = DEFAULT_MATERIALS_PAGE_SIZE,
}: MaterialListSectionProps) {
  const [page, setPage] = useState(1);
  const { data, isLoading, isError, error, refetch, isFetching } =
    useMaterialsQuery({ page, pageSize });

  if (isError && !data) {
    return (
      <div className="flex flex-col items-start gap-3">
        <Alert
          variant="error"
          message={mapMaterialError(error)}
          className="w-full"
        />
        <Button
          type="button"
          onClick={() => void refetch()}
          disabled={isFetching}
        >
          {isFetching ? 'Reintentando...' : 'Reintentar'}
        </Button>
      </div>
    );
  }

  return (
    <div aria-busy={isFetching}>
      {isError && (
        <Alert
          variant="error"
          message={mapMaterialError(error)}
          className="mb-4"
        />
      )}
      <MaterialList materials={data?.items ?? []} isLoading={isLoading} />
      {data && (
        <MaterialPagination
          page={page}
          totalPages={data.totalPages}
          total={data.total}
          disabled={isFetching}
          onPageChange={setPage}
        />
      )}
    </div>
  );
}
