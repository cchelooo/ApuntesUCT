import { Link } from 'react-router-dom';
import type { MaterialViewStatus } from '../../../domain/material/material';
 
interface MaterialUnavailableProps {
  status: Extract<MaterialViewStatus, 'unavailable' | 'not-found'>;
}
 
const COPY = {
  unavailable: {
    title: 'Este material no está disponible por ahora',
    body: 'No pudimos cargarlo. Vuelve al catálogo o inténtalo de nuevo en unos minutos.',
  },
  'not-found': {
    title: 'No encontramos este material',
    body: 'Puede que el enlace esté incompleto o que el material ya no exista.',
  },
} as const;
 
export function MaterialUnavailable({ status }: MaterialUnavailableProps) {
  const { title, body } = COPY[status];
 
  return (
    <div
      role="status"
      className="rounded-sm border border-dashed border-catalog-line bg-catalog-paperMuted px-6 py-12 text-center"
    >
      <p className="font-display text-lg text-catalog-ink">{title}</p>
      <p className="mx-auto mt-1 max-w-md text-sm text-catalog-ink/60">{body}</p>
      <Link
        to="/catalog"
        className="mt-5 inline-block rounded-sm p-2 text-sm font-medium text-catalog-maroon underline underline-offset-2 focus:outline-none focus:ring-2 focus:ring-catalog-maroon"
      >
        Volver al catálogo
      </Link>
    </div>
  );
}