import { useMemo } from 'react';
import { useCatalogNamesQuery } from '../../../application/catalog/useCatalogNamesQuery';
import { resolveMaterialNames } from '../../../application/material/resolveMaterialNames';
import type { SearchResultPage } from '../../../domain/search/search';
import { mapMaterialError } from '../../../infrastructure/material/materialErrorHandler';
import { Alert } from '../Alert';
import { Button } from '../Button';
import { MaterialList } from '../material/MaterialList';
import { MaterialPagination } from '../material/MaterialPagination';

interface SearchResultsProps {
  query: string;
  data?: SearchResultPage;
  isLoading: boolean;
  isFetching: boolean;
  isError: boolean;
  error: unknown;
  onRetry: () => void;
  onPageChange: (page: number) => void;
}

export function SearchResults({
  query,
  data,
  isLoading,
  isFetching,
  isError,
  error,
  onRetry,
  onPageChange,
}: SearchResultsProps) {
  const { data: names } = useCatalogNamesQuery();
  const materials = useMemo(
    () => resolveMaterialNames(data?.items ?? [], names),
    [data, names]
  );

  if (isError && !data) {
    return (
      <div className="flex flex-col items-start gap-3">
        <Alert
          variant="error"
          message={mapMaterialError(error, 'general')}
          className="w-full"
        />
        <Button type="button" onClick={onRetry} disabled={isFetching}>
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
          message={mapMaterialError(error, 'general')}
          className="mb-4"
        />
      )}
      {data && !isLoading && (
        <p className="mb-3 text-xs text-catalog-ink/50" aria-live="polite">
          {data.total} resultados para “{query}”
        </p>
      )}
      <MaterialList
        materials={materials}
        isLoading={isLoading}
        emptyTitle={`Sin resultados para “${query}”`}
        emptyDescription="Prueba con otras palabras o revisa la ortografía."
      />
      {data && (
        <MaterialPagination
          page={data.page}
          totalPages={data.totalPages}
          total={data.total}
          disabled={isFetching}
          onPageChange={onPageChange}
        />
      )}
    </div>
  );
}
