import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { CatalogFilterSidebar } from './CatalogFilterSidebar';
import { universitiesMock } from '../../../infrastructure/catalog/universities.mock';
import { careersMock } from '../../../infrastructure/catalog/careers.mock';
import { professorsMock } from '../../../infrastructure/catalog/professors.mock';

function careersOf(universityId: string) {
  return careersMock.filter((career) => career.universityId === universityId);
}

function getCareersPanel(universityId: string): HTMLElement {
  const panel = document.getElementById(`careers-${universityId}`);
  expect(panel).not.toBeNull();
  return panel as HTMLElement;
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
    expect(restUniversities.length).toBeGreaterThan(0);

    const firstUniversityCareers = careersOf(firstUniversity.id);
    expect(firstUniversityCareers.length).toBeGreaterThan(0);
    firstUniversityCareers.forEach((career) => {
      expect(screen.getByText(career.name)).toBeInTheDocument();
    });

    restUniversities.forEach((university) => {
      const careers = careersOf(university.id);
      expect(careers.length).toBeGreaterThan(0);
      careers.forEach((career) => {
        expect(screen.queryByText(career.name)).not.toBeInTheDocument();
      });
    });
  });

  it('respeta la jerarquía Universidad -> Carrera: cada panel expandido muestra únicamente sus propias carreras', async () => {
    const user = userEvent.setup();
    render(<CatalogFilterSidebar />);

    const [uct, ufro] = universitiesMock;
    expect(uct).toBeDefined();
    expect(ufro).toBeDefined();

    const uctCareers = careersOf(uct.id);
    const ufroCareers = careersOf(ufro.id);
    expect(uctCareers.length).toBe(4);
    expect(ufroCareers.length).toBe(2);
    const showUfroButton = screen.getByRole('button', {
      name: `Mostrar carreras de ${ufro.name}`,
    });
    await user.click(showUfroButton);

    const uctPanel = within(getCareersPanel(uct.id));
    const ufroPanel = within(getCareersPanel(ufro.id));

    uctCareers.forEach((career) => {
      expect(uctPanel.getByText(career.name)).toBeInTheDocument();
      expect(ufroPanel.queryByText(career.name)).not.toBeInTheDocument();
    });

    ufroCareers.forEach((career) => {
      expect(ufroPanel.getByText(career.name)).toBeInTheDocument();
      expect(uctPanel.queryByText(career.name)).not.toBeInTheDocument();
    });
  });

  it('permite expandir y colapsar las carreras de una universidad al hacer clic en el botón', async () => {
    const user = userEvent.setup();
    render(<CatalogFilterSidebar />);

    const secondUniversity = universitiesMock[1];
    expect(secondUniversity).toBeDefined();
    const secondUniversityCareers = careersOf(secondUniversity.id);
    expect(secondUniversityCareers.length).toBeGreaterThan(0);

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
    expect(firstUniversity).toBeDefined();
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
    expect(firstUniversity).toBeDefined();
    const [firstCareer] = careersOf(firstUniversity.id);
    expect(firstCareer).toBeDefined();

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
    expect(firstProfessor).toBeDefined();
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
    expect(firstUniversity).toBeDefined();
    const [firstCareer] = careersOf(firstUniversity.id);
    expect(firstCareer).toBeDefined();
    const firstProfessor = professorsMock[0];
    expect(firstProfessor).toBeDefined();

    const universityCheckbox = screen.getByRole('checkbox', {
      name: firstUniversity.name,
    });
    const careerCheckbox = screen.getByRole('checkbox', {
      name: firstCareer.name,
    });
    const professorCheckbox = screen.getByRole('checkbox', {
      name: firstProfessor.name,
    });

    await user.click(universityCheckbox);
    await user.click(careerCheckbox);
    await user.click(professorCheckbox);

    expect(universityCheckbox).toBeChecked();
    expect(careerCheckbox).toBeChecked();
    expect(professorCheckbox).toBeChecked();

    const clearButton = screen.getByRole('button', {
      name: 'Limpiar filtros',
    });
    await user.click(clearButton);

    expect(universityCheckbox).not.toBeChecked();
    expect(careerCheckbox).not.toBeChecked();
    expect(professorCheckbox).not.toBeChecked();
    expect(
      screen.queryByRole('button', { name: 'Limpiar filtros' })
    ).not.toBeInTheDocument();
  });
});
