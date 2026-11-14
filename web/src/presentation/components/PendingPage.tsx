import { Link } from 'react-router-dom';

interface PendingPageProps {
  title: string;
}

export function PendingPage({ title }: PendingPageProps) {
  return (
    <section className="bg-catalog-bg px-4 py-12 font-body text-catalog-ink sm:px-6 md:px-10 md:py-16">
      <div className="mx-auto max-w-2xl rounded-2xl border border-catalog-line bg-catalog-paper p-8 text-center shadow-xs sm:p-10">
        <div className="mx-auto mb-4 flex size-14 items-center justify-center rounded-full bg-catalog-paperMuted text-2xl text-uct-blue">
          👤
        </div>
        <h1 className="font-display text-2xl font-bold text-catalog-ink sm:text-3xl">
          {title}
        </h1>
        <div className="mx-auto my-3 h-1 w-12 rounded-full bg-uct-yellow" />
        <p className="mx-auto max-w-md text-sm leading-relaxed text-catalog-ink/70 sm:text-base">
          Esta sección está en desarrollo y estará disponible próximamente junto a la gestión de cuenta y aportes de la comunidad.
        </p>
        <p className="sr-only">{title} pendiente.</p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link
            to="/catalog"
            className="inline-flex min-h-11 items-center justify-center rounded-xl bg-uct-blue px-6 py-2.5 text-sm font-semibold text-white shadow-xs transition-colors hover:bg-uct-blueDark focus:outline-hidden focus:ring-2 focus:ring-uct-sky focus:ring-offset-2"
          >
            Explorar catálogo
          </Link>
          <Link
            to="/materials/upload"
            className="inline-flex min-h-11 items-center justify-center rounded-xl border border-catalog-line bg-catalog-paperMuted px-6 py-2.5 text-sm font-semibold text-catalog-ink transition-colors hover:bg-catalog-line/40 focus:outline-hidden focus:ring-2 focus:ring-catalog-primary"
          >
            Subir material
          </Link>
        </div>
      </div>
    </section>
  );
}
