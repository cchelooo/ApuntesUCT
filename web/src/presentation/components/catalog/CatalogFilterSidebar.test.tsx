import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { CatalogFilterSidebar } from './CatalogFilterSidebar';
import { universitiesMock } from '../../../infrastructure/catalog/universities.mock';
import { careersMock } from '../../../infrastructure/catalog/careers.mock';
import { professorsMock } from '../../../infrastructure/catalog/professors.mock';

function careersOf(universityId: string) {
  return careersMock.filter((career) => career.universityId === universityId);
}

describe('CatalogFilterSidebar', () => {
  it('renderiza todas las universidades del mock', () => {
    render(<CatalogFilterSidebar />);

    universitiesMock.forEach((university) => {
      expect(screen.getByText(university.name)).toBeInTheDocument();
    });
  });

  it('renderiza todos los profesores del mock', () => {
    render(<CatalogFilterSidebar />);

    professorsMock.forEach((professor) => {
      expect(screen.getByText(professor.name)).toBeInTheDocument();
    });
  });

  it('muestra expandidas las carreras de la primera universidad y colapsadas las demás', () => {
    render(<CatalogFilterSidebar />);

    const [firstUniversity, ...restUniversities] = universitiesMock;

    careersOf(firstUniversity.id).forEach((career) => {
      expect(screen.getByText(career.name)).toBeInTheDocument();
    });

    restUniversities.forEach((university) => {
      careersOf(university.id).forEach((career) => {
        expect(screen.queryByText(career.name)).not.toBeInTheDocument();
      });
    });
  });

  it('respeta la jerarquía Universidad -> Carrera: cada carrera solo aparece bajo su propia universidad', () => {
    render(<CatalogFilterSidebar />);
    const [firstUniversity, secondUniversity] = universitiesMock;
    if (!secondUniversity) return;

    const firstUniversityCareerNames = careersOf(firstUniversity.id).map(
      (career) => career.name
    );
    const secondUniversityCareerNames = careersOf(secondUniversity.id).map(
      (career) => career.name
    );

    firstUniversityCareerNames.forEach((name) => {
      expect(secondUniversityCareerNames).not.toContain(name);
    });
  });

  it('permite expandir y colapsar las carreras de una universidad al hacer clic en el botón', async () => {
    const user = userEvent.setup();
    render(<CatalogFilterSidebar />);

    const secondUniversity = universitiesMock[1];
    const secondUniversityCareers = careersOf(secondUniversity.id);
    if (secondUniversityCareers.length === 0) return;

    const showButton = screen.getByRole('button', {
      name: `Mostrar carreras de ${secondUniversity.name}`,
    });

    await user.click(showButton);

    secondUniversityCareers.forEach((career) => {
      expect(screen.getByText(career.name)).toBeInTheDocument();
    });

    const hideButton = screen.getByRole('button', {
      name: `Ocultar carreras de ${secondUniversity.name}`,
    });

    await user.click(hideButton);

    secondUniversityCareers.forEach((career) => {
      expect(screen.queryByText(career.name)).not.toBeInTheDocument();
    });
  });

  it('no muestra el botón "Limpiar filtros" cuando no hay filtros activos', () => {
    render(<CatalogFilterSidebar />);

    expect(
      screen.queryByRole('button', { name: 'Limpiar filtros' })
    ).not.toBeInTheDocument();
  });

  it('marca el checkbox de universidad al seleccionarlo y habilita "Limpiar filtros"', async () => {
    const user = userEvent.setup();
    render(<CatalogFilterSidebar />);

    const firstUniversity = universitiesMock[0];
    const universityCheckbox = screen.getByRole('checkbox', {
      name: firstUniversity.name,
    });

    await user.click(universityCheckbox);

    expect(universityCheckbox).toBeChecked();
    expect(
      screen.getByRole('button', { name: 'Limpiar filtros' })
    ).toBeInTheDocument();
  });

  it('marca el checkbox de una carrera visible dentro de la universidad expandida', async () => {
    const user = userEvent.setup();
    render(<CatalogFilterSidebar />);

    const firstUniversity = universitiesMock[0];
    const firstCareer = careersOf(firstUniversity.id)[0];
    if (!firstCareer) return;

    const careerCheckbox = screen.getByRole('checkbox', {
      name: firstCareer.name,
    });

    await user.click(careerCheckbox);

    expect(careerCheckbox).toBeChecked();
  });

  it('marca el checkbox de un profesor', async () => {
    const user = userEvent.setup();
    render(<CatalogFilterSidebar />);

    const firstProfessor = professorsMock[0];
    const professorCheckbox = screen.getByRole('checkbox', {
      name: firstProfessor.name,
    });

    await user.click(professorCheckbox);

    expect(professorCheckbox).toBeChecked();
  });

  it('limpia universidades, carreras y profesores seleccionados al hacer clic en "Limpiar filtros"', async () => {
    const user = userEvent.setup();
    render(<CatalogFilterSidebar />);

    const firstUniversity = universitiesMock[0];
    const firstCareer = careersOf(firstUniversity.id)[0];
    const firstProfessor = professorsMock[0];

    const universityCheckbox = screen.getByRole('checkbox', {
      name: firstUniversity.name,
    });
    const professorCheckbox = screen.getByRole('checkbox', {
      name: firstProfessor.name,
    });

    await user.click(universityCheckbox);
    await user.click(professorCheckbox);

    let careerCheckbox: HTMLElement | null = null;
    if (firstCareer) {
      careerCheckbox = screen.getByRole('checkbox', {
        name: firstCareer.name,
      });
      await user.click(careerCheckbox);
      expect(careerCheckbox).toBeChecked();
    }

    expect(universityCheckbox).toBeChecked();
    expect(professorCheckbox).toBeChecked();

    const clearButton = screen.getByRole('button', {
      name: 'Limpiar filtros',
    });
    await user.click(clearButton);

    expect(universityCheckbox).not.toBeChecked();
    expect(professorCheckbox).not.toBeChecked();
    if (careerCheckbox) {
      expect(careerCheckbox).not.toBeChecked();
    }
    expect(
      screen.queryByRole('button', { name: 'Limpiar filtros' })
    ).not.toBeInTheDocument();
  });
});
