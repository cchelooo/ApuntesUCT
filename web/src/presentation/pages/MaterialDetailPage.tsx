import type { ReactNode } from 'react';
import { Link, useParams } from 'react-router-dom';
import type {
  MaterialDetail,
  MaterialViewStatus,
} from '../../domain/material/material';
import { MaterialMetadata } from '../components/material/MaterialMetadata';
import { MaterialUnavailable } from '../components/material/MaterialUnavailable';
import { MaterialVersionCard } from '../components/material/MaterialVersionCard';

interface MaterialDetailPageProps {
  versionUpload?: ReactNode;
  materialId?: string;
  material?: MaterialDetail | null;
  status?: MaterialViewStatus;
}

export function MaterialDetailPage({
  versionUpload,
  materialId: materialIdProp,
  material = null,
  status = 'ready',
}: MaterialDetailPageProps) {
  const params = useParams<{ materialId: string }>();
  const materialId = materialIdProp ?? params.materialId;
  const effectiveStatus: MaterialViewStatus = materialId ? status : 'not-found';

  return (
    <section className="min-w-0 overflow-x-hidden bg-catalog-bg px-4 py-8 font-body text-catalog-ink sm:px-6 md:px-10 md:py-10">
      <div className="mx-auto min-w-0 max-w-5xl">
        <nav aria-label="Ruta de navegación" className="text-sm">
          <Link
            to="/catalog"
            className="rounded-xs p-1 text-catalog-ink/70 hover:text-catalog-ink focus:outline-hidden focus:ring-2 focus:ring-catalog-primary"
          >
            Catálogo
          </Link>
          <span className="mx-1 text-catalog-ink/40" aria-hidden="true">
            /
          </span>
          <span aria-current="page" className="text-catalog-ink">
            Material
          </span>
        </nav>

        {effectiveStatus === 'unavailable' ||
        effectiveStatus === 'not-found' ? (
          <div className="mt-6">
            <MaterialUnavailable status={effectiveStatus} />
          </div>
        ) : (
          <>
            <header className="mt-4 min-w-0">
              <h1 className="min-w-0 max-w-full break-words font-display text-3xl text-catalog-ink [overflow-wrap:anywhere] sm:text-4xl">
                {effectiveStatus === 'loading'
                  ? 'Cargando material…'
                  : (material?.title ?? 'Detalle del material')}
              </h1>
              <p className="mt-1 font-mono text-xs text-catalog-ink/50">
                ID: <span data-testid="material-id">{materialId}</span>
              </p>
            </header>

            <div
              className={`mt-8 grid grid-cols-1 items-start gap-6 lg:grid-cols-[minmax(0,9fr)_minmax(0,11fr)] ${
                effectiveStatus === 'loading' ? 'animate-pulse' : ''
              }`}
              aria-busy={effectiveStatus === 'loading'}
            >
              <MaterialMetadata material={material} />
              <div className="flex min-w-0 flex-col gap-4">
                {material?.versions?.length ? (
                  <>
                    <h2 className="font-display text-xl">
                      Historial de versiones
                    </h2>
                    <div
                      role="region"
                      aria-label="Versiones disponibles"
                      tabIndex={0}
                      className="flex max-h-[36rem] min-w-0 flex-col gap-3 overflow-y-auto rounded-xs focus-visible:outline-2 focus-visible:outline-catalog-primary"
                    >
                      {material.versions.map((version) => (
                        <MaterialVersionCard
                          key={version.id}
                          compact
                          version={version}
                          isCurrent={version.id === material.version?.id}
                          downloadUrl={version.downloadUrl}
                        />
                      ))}
                    </div>
                  </>
                ) : (
                  <MaterialVersionCard
                    version={material?.version}
                    downloadUrl={material?.downloadUrl}
                  />
                )}
                {effectiveStatus === 'ready' &&
                  material?.type !== 'LINK' &&
                  versionUpload}
              </div>
            </div>
          </>
        )}
      </div>
    </section>
  );
}
