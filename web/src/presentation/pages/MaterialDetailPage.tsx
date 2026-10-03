import { Link, useParams } from 'react-router-dom';
import type {
  MaterialDetail,
  MaterialViewStatus,
} from '../../domain/material/material';
import { MaterialMetadata } from '../components/material/MaterialMetadata';
import { MaterialUnavailable } from '../components/material/MaterialUnavailable';
import { MaterialVersionCard } from '../components/material/MaterialVersionCard';
 
interface MaterialDetailPageProps {
    materialId?: string;
    material?: MaterialDetail | null;
  status?: MaterialViewStatus;
}
 
export function MaterialDetailPage({
  materialId: materialIdProp,
  material = null,
  status = 'ready',
}: MaterialDetailPageProps) {
  const params = useParams<{ materialId: string }>();
  const materialId = materialIdProp ?? params.materialId;
  const effectiveStatus: MaterialViewStatus = materialId
    ? status
    : 'not-found';
 
  return (
    <section className="bg-catalog-bg px-4 py-8 font-body text-catalog-ink sm:px-6 md:px-10 md:py-10">
      <div className="mx-auto max-w-5xl">
        <nav aria-label="Ruta de navegación" className="text-sm">
          <Link
            to="/catalog"
            className="rounded-sm p-1 text-catalog-ink/70 hover:text-catalog-ink focus:outline-none focus:ring-2 focus:ring-catalog-maroon"
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
            <header className="mt-4">
              <h1 className="font-display text-3xl text-catalog-ink sm:text-4xl">
                {effectiveStatus === 'loading'
                  ? 'Cargando material…'
                  : (material?.title ?? 'Detalle del material')}
              </h1>
              <p className="mt-1 font-mono text-xs text-catalog-ink/50">
                ID: <span data-testid="material-id">{materialId}</span>
              </p>
            </header>
 
            <div
              className={`mt-8 grid grid-cols-1 gap-6 lg:grid-cols-[1fr_20rem] ${
                effectiveStatus === 'loading' ? 'animate-pulse' : ''
              }`}
              aria-busy={effectiveStatus === 'loading'}
            >
              <MaterialMetadata material={material} />
              <MaterialVersionCard
                version={material?.version}
                downloadUrl={material?.downloadUrl}
              />
            </div>
          </>
        )}
      </div>
    </section>
  );
}