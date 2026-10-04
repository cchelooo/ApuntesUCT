import type { MaterialListItem } from '../../../domain/material/materialListItem';
import { MaterialCard } from './MaterialCard';
import { MaterialCardSkeleton } from './MaterialCardSkeleton';

interface MaterialListProps {
  materials?: MaterialListItem[];
  isLoading?: boolean;
  skeletonCount?: number;
  emptyTitle?: string;
  emptyDescription?: string;
}

export function MaterialList({
  materials = [],
  isLoading = false,
  skeletonCount = 4,
  emptyTitle = 'Aún no hay materiales',
  emptyDescription = 'Cuando se suban materiales para esta selección, aparecerán aquí.',
}: MaterialListProps) {
  if (isLoading) {
    return (
      <div aria-busy="true">
        <p role="status" className="sr-only">
          Cargando materiales…
        </p>
        <ul className="flex flex-col gap-3">
          {Array.from({ length: skeletonCount }).map((_, index) => (
            <li key={index}>
              <MaterialCardSkeleton />
            </li>
          ))}
        </ul>
      </div>
    );
  }

  if (materials.length === 0) {
    return (
      <div
        role="status"
        className="rounded-sm border border-dashed border-catalog-line bg-catalog-paperMuted px-6 py-12 text-center"
      >
        <p className="font-display text-lg text-catalog-ink">{emptyTitle}</p>
        <p className="mx-auto mt-1 max-w-md text-sm text-catalog-ink/60">
          {emptyDescription}
        </p>
      </div>
    );
  }

  return (
    <ul className="flex flex-col gap-3">
      {materials.map((material) => (
        <li key={material.id}>
          <MaterialCard material={material} />
        </li>
      ))}
    </ul>
  );
}
