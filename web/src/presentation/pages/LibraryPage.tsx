import { Link } from 'react-router-dom';
import { MaterialListSection } from '../components/material/MaterialListSection';

export function LibraryPage() {
  return (
    <section className="bg-catalog-bg px-4 py-8 font-body text-catalog-ink sm:px-6 md:px-10 md:py-10">
      <div className="mx-auto max-w-5xl">
        <header className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="font-display text-3xl text-catalog-ink sm:text-4xl">
              Biblioteca
            </h1>
            <p className="mt-2 max-w-md text-sm text-catalog-ink/70">
              Materiales compartidos por la comunidad.
            </p>
          </div>
          <Link
            to="/materials/upload"
            className="inline-flex min-h-10 items-center justify-center rounded-xl bg-uct-blue px-4 py-2 text-sm font-semibold text-white shadow-xs transition-colors hover:bg-uct-blueDark focus:outline-hidden focus:ring-2 focus:ring-uct-sky focus:ring-offset-2 self-start sm:self-auto"
          >
            Subir material
          </Link>
        </header>
        <MaterialListSection />
      </div>
    </section>
  );
}
