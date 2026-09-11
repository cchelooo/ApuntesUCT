import { Link } from 'react-router-dom';

export function HomePage() {
  return (
    <section>
      <h1>El mejor material para tus pruebas, ordenado por profesor</h1>
      <p>
        Apuntes, resúmenes y recursos académicos organizados por carrera,
        asignatura y docente.
      </p>
      <Link to="/catalog">Explorar catálogo</Link>
    </section>
  );
}
