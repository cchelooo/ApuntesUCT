import { Link, Outlet } from 'react-router-dom';

export function MainLayout() {
  return (
    <div className="app-shell">
      <header className="app-header">
        <Link to="/" className="brand">
          ApuntesUCT
        </Link>
        <nav>
          <Link to="/catalog">Catálogo</Link>
          <Link to="/search">Búsqueda</Link>
          <Link to="/library">Biblioteca</Link>
          <Link to="/profile">Perfil</Link>
        </nav>
      </header>

      <main className="app-content">
        <Outlet />
      </main>

      <footer className="app-footer">
        <small>© 2026 ApuntesUCT</small>
      </footer>
    </div>
  );
}
