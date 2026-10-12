import { Link, Outlet } from 'react-router-dom';

export function MainLayout() {
  return (
    <div className="flex min-h-screen flex-col bg-catalog-bg">
      <header className="flex flex-wrap items-center justify-between border-b-4 border-uct-yellow bg-catalog-paper px-4 py-3 sm:px-6">
        <Link
          to="/"
          className="font-display text-xl font-bold text-catalog-ink"
        >
          ApuntesUCT
        </Link>
        <nav className="mt-3 flex w-full flex-wrap items-center justify-between gap-2 sm:mt-0 sm:w-auto sm:justify-end sm:gap-6">
          <Link
            to="/catalog"
            className="p-2 text-sm font-medium text-catalog-ink/80 hover:text-catalog-ink focus:outline-hidden focus:ring-2 focus:ring-catalog-primary rounded-xs"
          >
            Catálogo
          </Link>
          <Link
            to="/search"
            className="p-2 text-sm font-medium text-catalog-ink/80 hover:text-catalog-ink focus:outline-hidden focus:ring-2 focus:ring-catalog-primary rounded-xs"
          >
            Búsqueda
          </Link>
          <Link
            to="/library"
            className="p-2 text-sm font-medium text-catalog-ink/80 hover:text-catalog-ink focus:outline-hidden focus:ring-2 focus:ring-catalog-primary rounded-xs"
          >
            Biblioteca
          </Link>
          <Link
            to="/profile"
            className="p-2 text-sm font-medium text-catalog-ink/80 hover:text-catalog-ink focus:outline-hidden focus:ring-2 focus:ring-catalog-primary rounded-xs"
          >
            Perfil
          </Link>
        </nav>
      </header>

      <main className="flex-1 w-full">
        <Outlet />
      </main>

      <footer className="mt-auto border-t border-catalog-line bg-catalog-paper px-4 py-6 text-center">
        <small className="text-sm text-catalog-ink/60">© 2026 ApuntesUCT</small>
      </footer>
    </div>
  );
}
