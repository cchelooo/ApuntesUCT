import { MaterialListSection } from '../components/material/MaterialListSection';

export function LibraryPage() {
  return (
    <section className="bg-catalog-bg px-4 py-8 font-body text-catalog-ink sm:px-6 md:px-10 md:py-10">
      <div className="mx-auto max-w-5xl">
        <header className="mb-6">
          <h1 className="font-display text-3xl text-catalog-ink sm:text-4xl">
            Biblioteca
          </h1>
          <p className="mt-2 max-w-md text-sm text-catalog-ink/70">
            Materiales compartidos por la comunidad.
          </p>
        </header>
        <MaterialListSection />
      </div>
    </section>
  );
}
