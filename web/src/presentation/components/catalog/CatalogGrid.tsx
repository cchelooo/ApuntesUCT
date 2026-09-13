import type { Subject } from '../../../domain/catalog/subject';
import { CatalogCard } from './CatalogCard';
 
interface CatalogGridProps {
  subjects: Subject[];
  query: string;
}
 
export function CatalogGrid({ subjects, query }: CatalogGridProps) {
  if (subjects.length === 0) {
    return (
      <div className="rounded-sm border border-dashed border-catalog-line bg-catalog-paperMuted px-6 py-12 text-center">
        <p className="font-display text-lg text-catalog-ink">No hay asignaturas para “{query}”</p>
        <p className="mt-1 text-sm text-catalog-ink/60">
          Prueba buscando por otro nombre o por el código de la asignatura.
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