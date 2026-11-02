import { Button } from '../Button';

interface MaterialPaginationProps {
  page: number;
  totalPages: number;
  total: number;
  disabled?: boolean;
  onPageChange: (page: number) => void;
}

export function MaterialPagination({
  page,
  totalPages,
  total,
  disabled = false,
  onPageChange,
}: MaterialPaginationProps) {
  if (totalPages <= 1) return null;

  return (
    <nav
      aria-label="Paginación de materiales"
      className="mt-6 flex flex-wrap items-center justify-between gap-3"
    >
      <p className="text-sm text-catalog-ink/60">
        Página {page} de {totalPages} · {total} materiales
      </p>
      <div className="flex gap-2">
        <Button
          type="button"
          variant="secondary"
          size="sm"
          disabled={disabled || page <= 1}
          onClick={() => onPageChange(page - 1)}
        >
          Anterior
        </Button>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          disabled={disabled || page >= totalPages}
          onClick={() => onPageChange(page + 1)}
        >
          Siguiente
        </Button>
      </div>
    </nav>
  );
}
