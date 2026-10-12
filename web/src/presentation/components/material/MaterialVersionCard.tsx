import type { MaterialVersion } from '../../../domain/material/material';
import { MaterialDownloadButton } from './MaterialDownloadButton';

interface MaterialVersionCardProps {
  version?: MaterialVersion | null;
  downloadUrl?: string | null;
}

const EMPTY_VALUE = 'Por definir';

export function MaterialVersionCard({
  version,
  downloadUrl,
}: MaterialVersionCardProps) {
  const rows: Array<{ label: string; value: string | null | undefined }> = [
    { label: 'Subido por', value: version?.uploadedBy },
    { label: 'Fecha de subida', value: version?.uploadedAt },
    { label: 'Formato', value: version?.fileFormat },
    { label: 'Tamaño', value: version?.fileSizeLabel },
  ];

  return (
    <aside
      aria-labelledby="material-version-title"
      className="flex flex-col gap-5 rounded-xs border border-catalog-line bg-catalog-paper p-5"
    >
      <div className="flex items-baseline justify-between gap-2">
        <h2
          id="material-version-title"
          className="font-display text-lg text-catalog-ink"
        >
          Versión actual
        </h2>
        <span
          className="font-mono text-sm text-catalog-primary"
          data-testid="material-version-number"
        >
          {version ? `v${version.number}` : 'v—'}
        </span>
      </div>

      <dl className="flex flex-col gap-3">
        {rows.map(({ label, value }) => (
          <div key={label} className="flex justify-between gap-4 text-sm">
            <dt className="text-catalog-ink/60">{label}</dt>
            <dd
              className={`text-right ${
                value ? 'text-catalog-ink' : 'text-catalog-ink/40'
              }`}
            >
              {value ?? EMPTY_VALUE}
            </dd>
          </div>
        ))}
      </dl>

      <MaterialDownloadButton url={downloadUrl} />
    </aside>
  );
}
