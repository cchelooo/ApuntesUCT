import type { MaterialDetail } from '../../../domain/material/material';

interface MaterialMetadataProps {
  material?: MaterialDetail | null;
}

const EMPTY_VALUE = 'Por definir';

export function MaterialMetadata({ material }: MaterialMetadataProps) {
  const rows: Array<{
    label: string;
    value: string | number | null | undefined;
  }> = [
    { label: 'Asignatura', value: material?.subjectName },
    { label: 'Profesor', value: material?.professorName },
    { label: 'Tipo de material', value: material?.type },
    { label: 'Año', value: material?.year },
  ];

  return (
    <section
      aria-labelledby="material-metadata-title"
      className="rounded-xs border border-catalog-line bg-catalog-paper p-5"
    >
      <h2
        id="material-metadata-title"
        className="font-display text-lg text-catalog-ink"
      >
        Datos del material
      </h2>

      <p className="mt-3 text-sm leading-relaxed text-catalog-ink/70">
        {material?.description ?? 'La descripción del material aparecerá aquí.'}
      </p>

      <dl className="mt-5 grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-2">
        {rows.map(({ label, value }) => (
          <div key={label}>
            <dt className="text-xs text-catalog-ink/60">{label}</dt>
            <dd
              className={`mt-0.5 text-sm ${
                value ? 'text-catalog-ink' : 'text-catalog-ink/40'
              }`}
            >
              {value ?? EMPTY_VALUE}
            </dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
