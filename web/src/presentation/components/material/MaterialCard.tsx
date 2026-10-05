import { Link } from 'react-router-dom';
import type { MaterialListItem } from '../../../domain/material/materialListItem';

interface MaterialCardProps {
  material: MaterialListItem;
}

const TYPE_LABELS: Record<string, string> = {
  SUMMARY: 'Resumen',
  EXAM: 'Prueba',
  GUIDE: 'Guía',
  CLASS_NOTES: 'Apuntes de clase',
  OTHER: 'Otro',
};

const EMPTY_VALUE = 'Por definir';

function formatMaterialType(type: string | null): string {
  if (!type) return EMPTY_VALUE;
  return TYPE_LABELS[type] ?? type;
}

function DocumentIcon() {
  return (
    <svg
      viewBox="0 0 20 20"
      className="h-6 w-6 shrink-0 text-catalog-maroon"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      aria-hidden="true"
    >
      <path d="M5 3.5h7l3 3v10a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-12a1 1 0 0 1 1-1Z" />
      <path d="M12 3.5v3h3" />
      <path d="M6.5 10.5h7M6.5 13h5" />
    </svg>
  );
}

export function MaterialCard({ material }: MaterialCardProps) {
  const { id, title, subjectName, professorName, year, type } = material;

  return (
    <article className="rounded-sm border border-catalog-line bg-catalog-paper transition-colors focus-within:ring-2 focus-within:ring-catalog-maroon hover:bg-catalog-paperMuted">
      <Link
        to={`/material/${id}`}
        className="flex flex-wrap items-start gap-x-4 gap-y-3 p-4 focus:outline-none sm:flex-nowrap"
      >
        <DocumentIcon />

        <div className="min-w-0 flex-1">
          <h3 className="line-clamp-2 font-display text-lg leading-snug text-catalog-ink">
            {title}
          </h3>

          <dl className="mt-2 flex flex-col gap-1 text-sm">
            <div className="flex gap-2">
              <dt className="sr-only">Asignatura</dt>
              <dd
                className={`line-clamp-1 ${
                  subjectName ? 'text-catalog-ink/80' : 'text-catalog-ink/40'
                }`}
              >
                {subjectName ?? 'Asignatura por definir'}
              </dd>
            </div>
            <div className="flex gap-2">
              <dt className="sr-only">Profesor</dt>
              <dd
                className={`line-clamp-1 ${
                  professorName ? 'text-catalog-ink/60' : 'text-catalog-ink/40'
                }`}
              >
                {professorName ?? 'Profesor por definir'}
              </dd>
            </div>
          </dl>
        </div>
        <dl className="flex w-full flex-row flex-wrap items-center gap-x-3 gap-y-1 pl-10 text-sm sm:w-auto sm:shrink-0 sm:flex-col sm:items-end sm:pl-0 sm:text-right">
          <div>
            <dt className="sr-only">Tipo de material</dt>
            <dd className="rounded-sm border border-catalog-line bg-catalog-paperMuted px-2 py-0.5 text-xs font-medium text-catalog-maroon">
              {formatMaterialType(type)}
            </dd>
          </div>
          <div>
            <dt className="sr-only">Año</dt>
            <dd
              className={`font-mono text-xs ${
                year ? 'text-catalog-ink/70' : 'text-catalog-ink/40'
              }`}
            >
              {year ?? 'Año por definir'}
            </dd>
          </div>
        </dl>
      </Link>
    </article>
  );
}
