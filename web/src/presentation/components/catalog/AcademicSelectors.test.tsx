import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { AcademicSelectors } from './AcademicSelectors';

vi.mock('../../../application/catalog/useCatalogUniversitiesQuery', () => ({
  useCatalogUniversitiesQuery: vi.fn(() => ({
    data: [
      { id: 'u1', name: 'Universidad 1' },
      { id: 'u2', name: 'Universidad 2' },
    ],
    isLoading: false,
    error: null,
  })),
}));

vi.mock('../../../application/catalog/useCatalogCareersQuery', () => ({
  useCatalogCareersQuery: vi.fn((universityId) => ({
    data: universityId
      ? [
          { id: 'c1', name: 'Carrera 1' },
          { id: 'c2', name: 'Carrera 2' },
        ]
      : [],
    isLoading: false,
    error: null,
  })),
}));

vi.mock('../../../application/catalog/useCatalogSubjectsByCareerQuery', () => ({
  useCatalogSubjectsByCareerQuery: vi.fn((careerId) => ({
    data: careerId
      ? [
          { id: 's1', name: 'Asignatura 1' },
          { id: 's2', name: 'Asignatura 2' },
        ]
      : [],
    isLoading: false,
    error: null,
  })),
}));

vi.mock('../../../application/catalog/useCatalogProfessorsQuery', () => ({
  useCatalogProfessorsQuery: vi.fn((subjectId) => ({
    data: subjectId ? [{ id: 'p1', name: 'Profesor 1' }] : [],
    isLoading: false,
    error: null,
  })),
}));

describe('AcademicSelectors', () => {
  it('reinicia carrera, asignatura y profesor al cambiar la universidad', async () => {
    const user = userEvent.setup();
    const onChangeMock = vi.fn();

    const initialSelection = {
      universityId: 'u1',
      careerId: 'c1',
      subjectId: 's1',
      professorId: 'p1',
    };

    render(
      <AcademicSelectors value={initialSelection} onChange={onChangeMock} />
    );

    const universitySelect = screen.getByLabelText('Universidad');

    await user.selectOptions(universitySelect, 'u2');

    expect(onChangeMock).toHaveBeenCalledWith({
      universityId: 'u2',
      careerId: '',
      subjectId: '',
      professorId: '',
    });
  });

  it('reinicia asignatura y profesor al cambiar la carrera', async () => {
    const user = userEvent.setup();
    const onChangeMock = vi.fn();

    const initialSelection = {
      universityId: 'u1',
      careerId: 'c1',
      subjectId: 's1',
      professorId: 'p1',
    };

    render(
      <AcademicSelectors value={initialSelection} onChange={onChangeMock} />
    );

    const careerSelect = screen.getByLabelText('Carrera');

    await user.selectOptions(careerSelect, 'c2');

    expect(onChangeMock).toHaveBeenCalledWith({
      universityId: 'u1',
      careerId: 'c2',
      subjectId: '',
      professorId: '',
    });
  });

  it('reinicia el profesor al cambiar la asignatura', async () => {
    const user = userEvent.setup();
    const onChangeMock = vi.fn();

    const initialSelection = {
      universityId: 'u1',
      careerId: 'c1',
      subjectId: 's1',
      professorId: 'p1',
    };

    render(
      <AcademicSelectors value={initialSelection} onChange={onChangeMock} />
    );

    const subjectSelect = screen.getByLabelText('Asignatura');

    await user.selectOptions(subjectSelect, 's2');

    expect(onChangeMock).toHaveBeenCalledWith({
      universityId: 'u1',
      careerId: 'c1',
      subjectId: 's2',
      professorId: '',
    });
  });
});
