import { Link } from 'react-router-dom';

export function HomePage() {
  return (
    <section className="flex min-h-screen flex-col items-center justify-center bg-catalog-bg px-4 py-12 text-center sm:px-6 lg:px-8">
      <div className="mx-auto max-w-3xl">
        <h1 className="font-display text-4xl font-bold tracking-tight text-catalog-ink sm:text-5xl md:text-6xl">
          El mejor material para tus pruebas, ordenado por profesor
        </h1>
        <p className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-catalog-ink/70 sm:text-xl">
          Apuntes, resúmenes y recursos académicos organizados por carrera,
          asignatura y docente.
        </p>
        <div className="mt-10 flex justify-center gap-4">
          <Link
            to="/catalog"
            className="inline-flex items-center justify-center rounded-md bg-uct-blue px-8 py-3.5 text-base font-semibold text-white shadow-xs transition-all hover:bg-uct-blueDark hover:shadow-md focus:outline-hidden focus:ring-2 focus:ring-uct-sky focus:ring-offset-2"
          >
            Explorar catálogo
          </Link>
        </div>
      </div>
    </section>
  );
}
