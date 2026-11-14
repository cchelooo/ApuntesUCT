import { Link } from 'react-router-dom';

export function NotFoundPage() {
  return (
    <section className="flex min-h-[60vh] flex-col items-center justify-center bg-catalog-bg px-4 py-16 text-center font-body text-catalog-ink sm:px-6">
      <div className="mx-auto max-w-md rounded-2xl border border-catalog-line bg-catalog-paper p-8 shadow-xs sm:p-10">
        <span className="font-display text-5xl font-bold text-uct-blue sm:text-6xl">
          404
        </span>
        <h1 className="mt-4 font-display text-2xl font-semibold text-catalog-ink sm:text-3xl">
          Página no encontrada
        </h1>
        <p className="mt-3 text-sm leading-relaxed text-catalog-ink/70">
          La página que buscas no existe o ha sido movida. Puedes volver al inicio o explorar el catálogo.
        </p>
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Link
            to="/"
            className="inline-flex min-h-11 items-center justify-center rounded-xl bg-uct-blue px-5 py-2.5 text-sm font-semibold text-white shadow-xs transition-colors hover:bg-uct-blueDark focus:outline-hidden focus:ring-2 focus:ring-uct-sky focus:ring-offset-2"
          >
            Volver al inicio
          </Link>
          <Link
            to="/catalog"
            className="inline-flex min-h-11 items-center justify-center rounded-xl border border-catalog-line bg-catalog-paperMuted px-5 py-2.5 text-sm font-semibold text-catalog-ink transition-colors hover:bg-catalog-line/40 focus:outline-hidden focus:ring-2 focus:ring-catalog-primary"
          >
            Explorar catálogo
          </Link>
        </div>
      </div>
    </section>
  );
}
