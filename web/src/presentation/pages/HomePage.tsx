import { useMemo } from 'react';
import { Link } from 'react-router-dom';
import { useCatalogNamesQuery } from '../../application/catalog/useCatalogNamesQuery';
import { useMaterialsQuery } from '../../application/material/useMaterialsQuery';
import { resolveMaterialNames } from '../../application/material/resolveMaterialNames';
import { MaterialCard } from '../components/material/MaterialCard';
import { MaterialCardSkeleton } from '../components/material/MaterialCardSkeleton';

export function HomePage() {
  const { data, isLoading, isError } = useMaterialsQuery({
    page: 1,
    pageSize: 4,
  });
  const { data: names } = useCatalogNamesQuery();

  const recentMaterials = useMemo(
    () => resolveMaterialNames(data?.items ?? [], names),
    [data?.items, names]
  );

  return (
    <div className="bg-catalog-bg px-4 py-8 font-body text-catalog-ink sm:px-6 md:px-10 md:py-12">
      <div className="mx-auto max-w-5xl space-y-12">
        {/* Encabezado Principal / Hero */}
        <section className="text-center sm:text-left">
          <h1 className="font-display text-3xl font-bold tracking-tight text-catalog-ink sm:text-4xl md:text-5xl">
            El mejor material para tus pruebas, ordenado por profesor
          </h1>
          <p className="mt-4 max-w-2xl text-base leading-relaxed text-catalog-ink/70 sm:text-lg">
            Apuntes, resúmenes y recursos académicos organizados por carrera,
            asignatura y docente.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            <Link
              to="/catalog"
              className="inline-flex items-center justify-center rounded-md bg-uct-blue px-6 py-2.5 text-sm font-semibold text-white shadow-xs transition-all hover:bg-uct-blueDark hover:shadow-md focus:outline-hidden focus:ring-2 focus:ring-uct-sky focus:ring-offset-2"
            >
              Explorar catálogo
            </Link>
            <Link
              to="/materials/upload"
              className="inline-flex items-center justify-center rounded-md border border-catalog-line bg-catalog-paper px-6 py-2.5 text-sm font-semibold text-catalog-ink shadow-xs transition-all hover:bg-catalog-paperMuted focus:outline-hidden focus:ring-2 focus:ring-catalog-primary"
            >
              Subir material
            </Link>
          </div>
        </section>

        {/* Sección: Materiales recientes / básicos (Material Service) */}
        <section
          aria-labelledby="recent-materials-heading"
          className="space-y-4"
        >
          <div className="flex items-baseline justify-between border-b border-catalog-line pb-2">
            <div>
              <h2
                id="recent-materials-heading"
                className="font-display text-xl font-bold text-catalog-ink sm:text-2xl"
              >
                Materiales recientes
              </h2>
              <p className="text-sm text-catalog-ink/60">
                Aportes básicos de la comunidad consumidos desde Material
                Service.
              </p>
            </div>
            <Link
              to="/library"
              className="text-sm font-medium text-catalog-primary hover:underline"
            >
              Ver biblioteca →
            </Link>
          </div>

          {isLoading ? (
            <div aria-busy="true" data-testid="recent-materials-loading">
              <p role="status" className="sr-only">
                Cargando materiales recientes…
              </p>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                {Array.from({ length: 4 }).map((_, index) => (
                  <MaterialCardSkeleton key={index} />
                ))}
              </div>
            </div>
          ) : isError ? (
            <div
              role="alert"
              className="rounded-xs border border-catalog-line bg-catalog-paperMuted p-6 text-center text-sm text-catalog-ink/70"
            >
              No fue posible cargar los materiales recientes en este momento.{' '}
              <Link to="/catalog" className="text-catalog-primary underline">
                Ir al catálogo general
              </Link>
              .
            </div>
          ) : recentMaterials.length === 0 ? (
            <div
              role="status"
              data-testid="empty-materials-state"
              className="rounded-xs border border-dashed border-catalog-line bg-catalog-paperMuted px-6 py-10 text-center"
            >
              <p className="font-display text-base font-semibold text-catalog-ink sm:text-lg">
                Aún no hay materiales registrados
              </p>
              <p className="mx-auto mt-1 max-w-md text-sm text-catalog-ink/60">
                Sé el primero en compartir guías, apuntes o evaluaciones con tus
                compañeros.
              </p>
              <div className="mt-4">
                <Link
                  to="/materials/upload"
                  className="inline-flex items-center justify-center rounded-md bg-uct-blue px-4 py-2 text-sm font-semibold text-white hover:bg-uct-blueDark"
                >
                  Subir primer material
                </Link>
              </div>
            </div>
          ) : (
            <div
              data-testid="recent-materials-grid"
              className="grid grid-cols-1 gap-4 sm:grid-cols-2"
            >
              {recentMaterials.map((material) => (
                <MaterialCard key={material.id} material={material} />
              ))}
            </div>
          )}
        </section>

        {/* Sección: Mejor calificados / Reputación (Preparada para Quality Service) */}
        <section aria-labelledby="top-rated-heading" className="space-y-4">
          <div className="flex items-baseline justify-between border-b border-catalog-line pb-2">
            <div className="flex items-center gap-3">
              <h2
                id="top-rated-heading"
                className="font-display text-xl font-bold text-catalog-ink sm:text-2xl"
              >
                Mejores calificados
              </h2>
              <span className="rounded-xs border border-catalog-line bg-catalog-paperMuted px-2 py-0.5 text-xs font-medium text-catalog-ink/60">
                Quality Service
              </span>
            </div>
          </div>

          <div
            data-testid="quality-service-placeholder"
            className="rounded-xs border border-catalog-line bg-catalog-paper p-6 sm:p-8"
          >
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div className="space-y-1">
                <h3 className="font-display text-base font-semibold text-catalog-ink">
                  Sección preparada para Quality Service
                </h3>
                <p className="max-w-2xl text-sm leading-relaxed text-catalog-ink/70">
                  Las calificaciones, reseñas y el posicionamiento por
                  reputación se integrarán con Quality Service. No se simulan
                  estrellas ni algoritmos artificiales de ranking en el cliente
                  web.
                </p>
              </div>
              <Link
                to="/catalog"
                className="inline-flex shrink-0 items-center justify-center rounded-md border border-catalog-line bg-catalog-paperMuted px-4 py-2 text-sm font-medium text-catalog-ink hover:bg-catalog-line/40"
              >
                Explorar catálogo
              </Link>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
