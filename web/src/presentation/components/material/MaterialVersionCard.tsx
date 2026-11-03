import { useId } from 'react';
import type { MaterialVersion } from '../../../domain/material/material';
import { MaterialDownloadButton } from './MaterialDownloadButton';

interface MaterialVersionCardProps {
  compact?: boolean;
  version?: MaterialVersion | null;
  isCurrent?: boolean;
  downloadUrl?: string | null;
}

const EMPTY_VALUE = 'Por definir';

export function MaterialVersionCard({
  compact = false,
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

  if (compact && version) {
    return (
      <aside
        aria-labelledby={titleId}
        className="min-w-0 shrink-0 rounded-xs border border-catalog-line bg-catalog-paper p-4"
      >
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span
            data-testid="material-version-number"
            className="font-mono text-sm font-semibold text-catalog-primary"
          >
            v{version.number}
          </span>
          <h3
            id={titleId}
            className={
              isCurrent
                ? 'rounded-full bg-catalog-paperMuted px-2 py-1 text-xs font-semibold text-catalog-primary'
                : 'text-xs text-catalog-ink/60'
            }
          >
            {isCurrent ? 'Versión actual' : 'Versión anterior'}
          </h3>
        </div>
        <p className="mt-2 min-w-0 break-words text-sm font-medium [overflow-wrap:anywhere]">
          {version.originalFilename ?? EMPTY_VALUE}
        </p>
        <div className="mt-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <dl className="flex min-w-0 flex-wrap gap-x-3 gap-y-1 text-xs text-catalog-ink/60">
            {[
              { label: 'Fecha de subida', value: version.uploadedAt },
              { label: 'Formato', value: version.fileFormat },
              { label: 'Tamaño', value: version.fileSizeLabel },
              { label: 'Subido por', value: version.uploadedBy },
            ]
              .filter((row) => row.value)
              .map(({ label, value }) => (
                <div key={label}>
                  <dt className="sr-only">{label}</dt>
                  <dd className="break-words">{value}</dd>
                </div>
              ))}
          </dl>
          <div className="shrink-0 sm:max-w-[55%]">
            <MaterialDownloadButton url={downloadUrl} />
          </div>
        </div>
      </aside>
    );
  }

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
