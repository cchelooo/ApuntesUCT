import { Link } from 'react-router-dom';
import { MaterialUploadForm } from '../components/material/MaterialUploadForm';

export function MaterialUploadPage({ accessToken }: { accessToken?: string }) {
  return (
    <div className="mx-auto max-w-6xl px-4 py-8 font-body sm:px-6 sm:py-12 lg:px-8">
      <Link
        to="/catalog"
        className="inline-flex min-h-11 items-center gap-2 rounded-md text-sm font-medium text-uct-blueDark hover:underline focus:outline-hidden focus:ring-2 focus:ring-uct-blue"
      >
        <span aria-hidden="true">←</span> Volver al catálogo
      </Link>
      <header className="mb-10 mt-5 max-w-2xl">
        <p className="mb-3 text-xs font-semibold uppercase tracking-widest text-uct-blueDark">
          Aprendemos en comunidad
        </p>
        <h1 className="text-3xl font-semibold tracking-tight text-uct-navy sm:text-4xl">
          Comparte lo que sabes
        </h1>
        <div className="mb-5 mt-4 h-1 w-12 rounded-full bg-uct-yellow" />
        <p className="text-base leading-relaxed text-uct-muted sm:text-lg">
          Dale una segunda vida a tus apuntes. Ayuda a otros estudiantes a
          preparar su próxima clase.
        </p>
      </header>
      <div className="grid min-w-0 items-start gap-8 lg:grid-cols-[minmax(0,1fr)_17rem]">
        <div className="min-w-0">
          <h2 className="mb-2 text-xl font-semibold text-uct-navy">
            Subir material
          </h2>
          <p className="mb-7 text-sm text-uct-muted">
            Completa los campos; descripción y profesor son opcionales.
          </p>
          <MaterialUploadForm accessToken={accessToken} />
        </div>
        <aside
          aria-labelledby="upload-advice"
          className="rounded-2xl border border-uct-border bg-catalog-paperMuted p-6 lg:mt-16"
        >
          <h2
            id="upload-advice"
            className="text-lg font-semibold text-uct-blueDark"
          >
            Un aporte que ayuda
          </h2>
          <ul className="mt-5 space-y-5 text-sm leading-relaxed text-uct-navy">
            <li>
              <strong className="mb-1 block">Fácil de encontrar</strong>Usa un
              título que indique el tema o la unidad.
            </li>
            <li>
              <strong className="mb-1 block">En el lugar correcto</strong>Asocia
              el material a su asignatura para que llegue a tus compañeros.
            </li>
            <li>
              <strong className="mb-1 block">Listo para estudiar</strong>Revisa
              que el archivo se lea bien o que el enlace sea accesible.
            </li>
          </ul>
          <p className="mt-6 border-t border-uct-border pt-5 text-sm text-uct-muted">
            Archivos de hasta{' '}
            <strong className="text-uct-blueDark">15 MB</strong> en PDF, Word o
            PowerPoint.
          </p>
        </aside>
      </div>
    </div>
  );
}
