import { useCatalogSubjects } from '../../application/catalog/useCatalogSubjects';
import { CatalogGrid } from '../components/catalog/CatalogGrid';

export function CatalogPage() {
  const { subjects, query, setQuery, total } = useCatalogSubjects();

  return (
    <section className="bg-catalog-bg px-6 py-10 font-body text-catalog-ink sm:px-10">
      <header className="mx-auto mb-8 max-w-6xl">
        <h1 className="font-display text-3xl text-catalog-ink sm:text-4xl">
          Catálogo
        </h1>
        <p className="mt-2 max-w-md text-sm text-catalog-ink/70">
          Explora las asignaturas disponibles y encuentra los apuntes que ha
          compartido la comunidad.
        </p>

        <label className="mt-6 flex max-w-sm items-center gap-2 rounded-sm border border-catalog-line bg-catalog-paper px-3 py-2">
          <span className="sr-only">
            Buscar asignaturas por nombre o código
          </span>
          <svg
            viewBox="0 0 20 20"
            className="h-4 w-4 shrink-0 text-catalog-ink/50"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.5"
            aria-hidden="true"
          >
            <circle cx="8.5" cy="8.5" r="5.5" />
            <path d="m16 16-3.2-3.2" />
          </svg>
          <input
            type="text"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Buscar por nombre o código"
            className="w-full bg-transparent text-sm text-catalog-ink placeholder:text-catalog-ink/40 focus:outline-none"
          />
        </label>

        <p className="mt-2 text-xs text-catalog-ink/50">
          {subjects.length} de {total} asignaturas
        </p>
      </header>

      <div className="mx-auto max-w-6xl">
        <CatalogGrid subjects={subjects} query={query} />
      </div>
    </section>
  );
}
