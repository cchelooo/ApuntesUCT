import { useId } from 'react';
import type { MaterialVersion } from '../../../domain/material/material';
import { MaterialDownloadButton } from './MaterialDownloadButton';

interface MaterialVersionCardProps {
  version?: MaterialVersion | null;
  isCurrent?: boolean;
  downloadUrl?: string | null;
}

const EMPTY_VALUE = 'Por definir';

export function MaterialVersionCard({
  version,
  downloadUrl,
  isCurrent = true,
}: MaterialVersionCardProps) {
  const titleId = useId();
  const rows: Array<{ label: string; value: string | null | undefined }> = [
    { label: 'Archivo', value: version?.originalFilename },
    { label: 'Subido por', value: version?.uploadedBy },
    { label: 'Fecha de subida', value: version?.uploadedAt },
    { label: 'Formato', value: version?.fileFormat },
    { label: 'Tamaño', value: version?.fileSizeLabel },
  ];

  return (
    <aside
      aria-labelledby={titleId}
      className="flex flex-col gap-5 rounded-xs border border-catalog-line bg-catalog-paper p-5"
    >
      <div className="flex items-baseline justify-between gap-2">
        <h2 id={titleId} className="font-display text-lg text-catalog-ink">
          {isCurrent ? 'Versión actual' : 'Versión anterior'}
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
          <div
            key={label}
            className="flex min-w-0 justify-between gap-4 text-sm"
          >
            <dt className="shrink-0 text-catalog-ink/60">{label}</dt>
            <dd
              className={`min-w-0 break-words text-right ${
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
