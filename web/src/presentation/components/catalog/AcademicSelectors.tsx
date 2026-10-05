import { useCatalogUniversitiesQuery } from '../../../application/catalog/useCatalogUniversitiesQuery';
import { useCatalogCareersQuery } from '../../../application/catalog/useCatalogCareersQuery';
import { useCatalogSubjectsByCareerQuery } from '../../../application/catalog/useCatalogSubjectsByCareerQuery';
import { useCatalogProfessorsQuery } from '../../../application/catalog/useCatalogProfessorsQuery';
import { Select } from '../Select';
import { Spinner } from '../Spinner';
import { Alert } from '../Alert';

export interface AcademicSelection {
  universityId: string;
  careerId: string;
  subjectId: string;
  professorId: string;
}

export interface AcademicSelectorsProps {
  value: AcademicSelection;
  onChange: (selection: AcademicSelection) => void;
  className?: string;
}

export const AcademicSelectors = ({
  value,
  onChange,
  className = '',
}: AcademicSelectorsProps) => {
  const {
    data: universities,
    isLoading: isLoadingUniversities,
    error: errorUniversities,
  } = useCatalogUniversitiesQuery();

  const {
    data: careers,
    isLoading: isLoadingCareers,
    error: errorCareers,
  } = useCatalogCareersQuery(value.universityId);

  const {
    data: subjects,
    isLoading: isLoadingSubjects,
    error: errorSubjects,
  } = useCatalogSubjectsByCareerQuery(value.careerId);

  const {
    data: professors,
    isLoading: isLoadingProfessors,
    error: errorProfessors,
  } = useCatalogProfessorsQuery(value.subjectId);

  const handleUniversityChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    onChange({
      universityId: e.target.value,
      careerId: '',
      subjectId: '',
      professorId: '',
    });
  };

  const handleCareerChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    onChange({
      ...value,
      careerId: e.target.value,
      subjectId: '',
      professorId: '',
    });
  };

  const handleSubjectChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    onChange({
      ...value,
      subjectId: e.target.value,
      professorId: '',
    });
  };

  const handleProfessorChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    onChange({
      ...value,
      professorId: e.target.value,
    });
  };

  const hasAnyError =
    errorUniversities || errorCareers || errorSubjects || errorProfessors;

  const isAnyLoading =
    isLoadingUniversities ||
    isLoadingCareers ||
    isLoadingSubjects ||
    isLoadingProfessors;

  return (
    <div className={`flex flex-col gap-4 ${className}`.trim()}>
      {hasAnyError && (
        <Alert
          variant="error"
          message="Ocurrió un problema al cargar los datos del catálogo. Por favor, intenta nuevamente."
        />
      )}

      <div className="flex items-center gap-2 mb-2">
        <h3 className="text-lg font-medium text-gray-800">
          Selección Académica
        </h3>
        {isAnyLoading && <Spinner size="sm" className="text-blue-600" />}
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <Select
          label="Universidad"
          placeholder="Selecciona una universidad..."
          value={value.universityId}
          onChange={handleUniversityChange}
          disabled={isLoadingUniversities || !!errorUniversities}
          options={(universities || []).map((u) => ({
            value: u.id,
            label: u.name,
          }))}
        />

        <Select
          label="Carrera"
          placeholder={
            !value.universityId
              ? 'Selecciona una universidad primero'
              : 'Selecciona una carrera...'
          }
          value={value.careerId}
          onChange={handleCareerChange}
          disabled={!value.universityId || isLoadingCareers || !!errorCareers}
          options={(careers || []).map((c) => ({
            value: c.id,
            label: c.name,
          }))}
        />

        <Select
          label="Asignatura"
          placeholder={
            !value.careerId
              ? 'Selecciona una carrera primero'
              : 'Selecciona una asignatura...'
          }
          value={value.subjectId}
          onChange={handleSubjectChange}
          disabled={!value.careerId || isLoadingSubjects || !!errorSubjects}
          options={(subjects || []).map((s) => ({
            value: s.id,
            label: s.name,
          }))}
        />

        <Select
          label="Profesor"
          placeholder={
            !value.subjectId
              ? 'Selecciona una asignatura primero'
              : 'Selecciona un profesor...'
          }
          value={value.professorId}
          onChange={handleProfessorChange}
          disabled={
            !value.subjectId || isLoadingProfessors || !!errorProfessors
          }
          options={(professors || []).map((p) => ({
            value: p.id,
            label: p.name,
          }))}
        />
      </div>
    </div>
  );
};
