import { useState, type Dispatch, type SetStateAction } from 'react';
import type { Career } from '../../../domain/catalog/career';
import { careersMock } from '../../../infrastructure/catalog/careers.mock';
import { professorsMock } from '../../../infrastructure/catalog/professors.mock';
import { universitiesMock } from '../../../infrastructure/catalog/universities.mock';

function careersByUniversity(universityId: string): Career[] {
  return careersMock.filter((career) => career.universityId === universityId);
}

function toggleInSet(setState: Dispatch<SetStateAction<Set<string>>>, id: string) {
  setState((prev) => {
    const next = new Set(prev);
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    return next;
  });
}

export function CatalogFilterSidebar() {
  const [openUniversities, setOpenUniversities] = useState<Set<string>>(
    () => new Set(universitiesMock.slice(0, 1).map((university) => university.id)),
  );
  const [checkedUniversities, setCheckedUniversities] = useState<Set<string>>(new Set());
  const [checkedCareers, setCheckedCareers] = useState<Set<string>>(new Set());
  const [checkedProfessors, setCheckedProfessors] = useState<Set<string>>(new Set());

  const hasActiveFilters =
    checkedUniversities.size > 0 || checkedCareers.size > 0 || checkedProfessors.size > 0;

  function clearFilters() {
    setCheckedUniversities(new Set());
    setCheckedCareers(new Set());
    setCheckedProfessors(new Set());
  }

  return (
    <aside
      className="w-full shrink-0 rounded-sm border border-catalog-line bg-catalog-paper lg:w-72"
      aria-label="Filtros del catálogo"
    >
      <div className="flex items-center justify-between border-b border-catalog-line px-4 py-3">
        <h2 className="font-display text-lg text-catalog-ink">Filtros</h2>
        {hasActiveFilters && (
          <button
            type="button"
            onClick={clearFilters}
            className="text-xs font-medium text-catalog-ink/60 underline-offset-2 hover:text-catalog-ink hover:underline"
          >
            Limpiar filtros
          </button>
        )}
      </div>

      <fieldset className="border-b border-catalog-line px-4 py-4">
        <legend className="font-display text-sm text-catalog-ink">Universidad</legend>

        <div className="mt-3 flex flex-col gap-3">
          {universitiesMock.map((university) => {
            const careers = careersByUniversity(university.id);
            const isOpen = openUniversities.has(university.id);
            const panelId = `careers-${university.id}`;

            return (
              <div key={university.id}>
                <div className="flex items-center gap-2">
                  <label className="flex flex-1 items-center gap-2 text-sm text-catalog-ink">
                    <input
                      type="checkbox"
                      checked={checkedUniversities.has(university.id)}
                      onChange={() => toggleInSet(setCheckedUniversities, university.id)}
                      className="h-4 w-4 rounded-sm border-catalog-line text-catalog-maroon focus:ring-catalog-maroon"
                    />
                    <span>{university.name}</span>
                  </label>

                  {careers.length > 0 && (
                    <button
                      type="button"
                      onClick={() => toggleInSet(setOpenUniversities, university.id)}
                      aria-expanded={isOpen}
                      aria-controls={panelId}
                      className="rounded-sm p-1 text-catalog-ink/50 hover:text-catalog-ink"
                    >
                      <span className="sr-only">
                        {isOpen ? 'Ocultar carreras de' : 'Mostrar carreras de'} {university.name}
                      </span>
                      <svg
                        viewBox="0 0 20 20"
                        className={`h-4 w-4 transition-transform ${isOpen ? 'rotate-180' : ''}`}
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        aria-hidden="true"
                      >
                        <path d="m6 8 4 4 4-4" />
                      </svg>
                    </button>
                  )}
                </div>

                {isOpen && careers.length > 0 && (
                  <div
                    id={panelId}
                    className="ml-6 mt-2 flex flex-col gap-2 border-l border-catalog-line pl-3"
                  >
                    {careers.map((career) => (
                      <label
                        key={career.id}
                        className="flex items-center gap-2 text-sm text-catalog-ink/80"
                      >
                        <input
                          type="checkbox"
                          checked={checkedCareers.has(career.id)}
                          onChange={() => toggleInSet(setCheckedCareers, career.id)}
                          className="h-4 w-4 rounded-sm border-catalog-line text-catalog-maroon focus:ring-catalog-maroon"
                        />
                        <span>{career.name}</span>
                      </label>
                    ))}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </fieldset>

      <fieldset className="px-4 py-4">
        <legend className="font-display text-sm text-catalog-ink">Profesor</legend>

        <div className="mt-3 flex max-h-56 flex-col gap-2 overflow-y-auto pr-1">
          {professorsMock.map((professor) => (
            <label key={professor.id} className="flex items-center gap-2 text-sm text-catalog-ink/80">
              <input
                type="checkbox"
                checked={checkedProfessors.has(professor.id)}
                onChange={() => toggleInSet(setCheckedProfessors, professor.id)}
                className="h-4 w-4 rounded-sm border-catalog-line text-catalog-maroon focus:ring-catalog-maroon"
              />
              <span>{professor.name}</span>
            </label>
          ))}
        </div>
      </fieldset>
    </aside>
  );
}