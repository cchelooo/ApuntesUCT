import { Link, Outlet } from 'react-router-dom';

export function MainLayout() {
  return (
    <div className="flex min-h-screen flex-col bg-catalog-bg">
      <header className="flex flex-wrap items-center justify-between border-b-4 border-uct-yellow bg-catalog-paper px-4 py-3 sm:px-6">
        <Link
          to="/"
          className="font-display text-xl font-bold text-catalog-ink shrink-0"
        >
          ApuntesUCT
        </Link>
        <nav className="mt-3 grid w-full grid-cols-4 items-center gap-1 text-center sm:mt-0 sm:flex sm:w-auto sm:flex-wrap sm:justify-end sm:gap-6">
          <Link
            to="/materials/upload"
            className="col-span-4 mb-2 inline-flex min-h-11 items-center justify-center rounded-xl bg-uct-blue px-4 py-2 text-sm font-semibold text-white hover:bg-uct-blueDark focus:outline-hidden focus:ring-2 focus:ring-uct-sky focus:ring-offset-2 sm:mb-0"
          >
            Subir material
          </Link>
          <Link
            to="/catalog"
            className="p-1.5 sm:p-2 text-xs sm:text-sm font-medium text-catalog-ink/80 hover:text-catalog-ink focus:outline-hidden focus:ring-2 focus:ring-catalog-primary rounded-xs truncate"
          >
            Catálogo
          </Link>
          <Link
            to="/search"
            className="p-1.5 sm:p-2 text-xs sm:text-sm font-medium text-catalog-ink/80 hover:text-catalog-ink focus:outline-hidden focus:ring-2 focus:ring-catalog-primary rounded-xs truncate"
          >
            Búsqueda
          </Link>
          <Link
            to="/library"
            className="p-1.5 sm:p-2 text-xs sm:text-sm font-medium text-catalog-ink/80 hover:text-catalog-ink focus:outline-hidden focus:ring-2 focus:ring-catalog-primary rounded-xs truncate"
          >
            Biblioteca
          </Link>
          <Link
            to="/profile"
            className="p-1.5 sm:p-2 text-xs sm:text-sm font-medium text-catalog-ink/80 hover:text-catalog-ink focus:outline-hidden focus:ring-2 focus:ring-catalog-primary rounded-xs truncate"
          >
            Perfil
          </Link>
        </nav>
      </header>

      <main className="flex-1 w-full">
        <Outlet />
      </main>

      <footer className="mt-auto border-t border-catalog-line bg-catalog-paper px-4 py-6">
        <div className="mx-auto flex max-w-5xl flex-col items-center justify-between gap-4 text-center sm:flex-row sm:text-left">
          <div className="flex flex-col gap-1">
            <span className="font-display text-base font-bold text-catalog-ink">
              ApuntesUCT
            </span>
            <small className="text-xs text-catalog-ink/60">
              © 2026 ApuntesUCT · Comunidad académica y repositorio colaborativo.
            </small>
          </div>
          <div className="flex flex-wrap items-center justify-center gap-4 text-xs font-medium text-catalog-ink/70">
            <Link to="/catalog" className="hover:text-catalog-ink hover:underline">
              Catálogo
            </Link>
            <Link to="/library" className="hover:text-catalog-ink hover:underline">
              Biblioteca
            </Link>
            <Link to="/search" className="hover:text-catalog-ink hover:underline">
              Búsqueda
            </Link>
            <Link to="/login" className="hover:text-catalog-ink hover:underline">
              Ingresar
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
