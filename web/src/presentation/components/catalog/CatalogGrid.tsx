import type { Subject } from '../../../domain/catalog/subject';
import { CatalogCard } from './CatalogCard';

interface CatalogGridProps {
  subjects: Subject[];
  query: string;
}

export function CatalogGrid({ subjects, query }: CatalogGridProps) {
  if (subjects.length === 0) {
    return (
      <div
        role="status"
        className="rounded-xs border border-dashed border-catalog-line bg-catalog-paperMuted px-6 py-12 text-center"
      >
        <p className="font-display text-lg text-catalog-ink break-words">
          {query.trim()
            ? `No hay asignaturas para “${query}”`
            : 'Todavía no hay asignaturas disponibles'}
        </p>
        <p className="mt-1 text-sm text-catalog-ink/60">
          {query.trim()
            ? 'Prueba buscando por otro nombre o por el código de la asignatura.'
            : 'Las asignaturas aparecerán aquí cuando estén disponibles en el catálogo.'}
        </p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      {subjects.map((subject) => (
        <CatalogCard key={subject.id} subject={subject} />
      ))}
    </div>
  );
}
