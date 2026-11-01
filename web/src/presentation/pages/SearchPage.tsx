import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  buildSearchParams,
  parseSearchUrl,
  type SearchUrlState,
} from '../../application/search/searchUrlState';
import { useSearchQuery } from '../../application/search/useSearchQuery';
import {
  SEARCH_TYPE_OPTIONS,
  SEARCH_YEAR_MAX,
  SEARCH_YEAR_MIN,
  hasSearchFilters,
  normalizeSearchFilters,
  parseSearchYear,
  type SearchSort,
} from '../../domain/search/search';
import { DEFAULT_SEARCH_PAGE_SIZE } from '../../infrastructure/search/searchApi';
import { Button } from '../components/Button';
import {
  AcademicSelectors,
  type AcademicSelection,
} from '../components/catalog/AcademicSelectors';
import { Input } from '../components/Input';
import { Select } from '../components/Select';
import { SearchResults } from '../components/search/SearchResults';
import { SearchSortSelect } from '../components/search/SearchSortSelect';

const YEAR_ERROR = `El año debe estar entre ${SEARCH_YEAR_MIN} y ${SEARCH_YEAR_MAX}.`;

export function SearchPage() {
  const [params, setParams] = useSearchParams();
  const state = parseSearchUrl(params);
  const { q, sort, page, filters } = state;

  const [draft, setDraft] = useState(q);
  const [yearDraft, setYearDraft] = useState<string | null>(null);
  const [yearError, setYearError] = useState<string | null>(null);

  const hasCriteria = q.length > 0 || hasSearchFilters(filters);
  const hasFiltersToClear =
    hasSearchFilters(filters) || Boolean(yearDraft?.trim());

  const { data, isLoading, isFetching, isError, error, refetch } =
    useSearchQuery({
      q,
      sort,
      page,
      pageSize: DEFAULT_SEARCH_PAGE_SIZE,
      filters,
    });

  function update(next: Partial<SearchUrlState>) {
    const merged: SearchUrlState = {
      ...state,
      ...next,
      page: next.page ?? 1,
    };
    merged.filters = normalizeSearchFilters(merged.filters);
    setParams(buildSearchParams(merged));
  }

  function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    const rawYear = (
      yearDraft ?? (filters.year !== undefined ? String(filters.year) : '')
    ).trim();
    let year: number | undefined;
    if (rawYear) {
      year = parseSearchYear(rawYear);
      if (year === undefined) {
        setYearError(YEAR_ERROR);
        return;
      }
    }
    setYearError(null);
    setYearDraft(null);
    update({ q: draft.trim(), filters: { ...filters, year } });
  }

  function handleAcademicChange(selection: AcademicSelection) {
    update({
      filters: {
        ...filters,
        universityId: selection.universityId,
        careerId: selection.careerId,
        subjectId: selection.subjectId,
        professorId: selection.professorId,
      },
    });
  }

  function handleClearFilters() {
    setYearDraft(null);
    setYearError(null);
    update({ filters: {} });
  }

  const academicValue: AcademicSelection = {
    universityId: filters.universityId ?? '',
    careerId: filters.careerId ?? '',
    subjectId: filters.subjectId ?? '',
    professorId: filters.professorId ?? '',
  };

  const typeOptions = SEARCH_TYPE_OPTIONS.some(
    (option) => option.value === (filters.type ?? '')
  )
    ? SEARCH_TYPE_OPTIONS.map((option) => ({ ...option }))
    : [
        ...SEARCH_TYPE_OPTIONS.map((option) => ({ ...option })),
        { value: filters.type!, label: filters.type! },
      ];

  return (
    <section className="bg-catalog-bg px-4 py-8 font-body text-catalog-ink sm:px-6 md:px-10 md:py-10">
      <div className="mx-auto max-w-5xl">
        <header className="mb-6">
          <h1 className="font-display text-3xl text-catalog-ink sm:text-4xl">
            Búsqueda
          </h1>
          <p className="mt-2 max-w-md text-sm text-catalog-ink/70">
            Encuentra apuntes, pruebas y guías compartidos por la comunidad.
          </p>
        </header>

        <form
          role="search"
          className="mb-6 flex flex-col gap-5"
          onSubmit={handleSubmit}
          noValidate
        >
          <div className="flex flex-col gap-4 sm:flex-row sm:items-end">
            <Input
              label="Buscar materiales"
              type="search"
              name="q"
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              placeholder="Ej. Estructuras de datos certamen"
              containerClassName="flex-1"
            />
            <SearchSortSelect
              value={sort}
              onChange={(next: SearchSort) => update({ sort: next })}
            />
            <Button type="submit" className="min-h-10">
              Buscar
            </Button>
          </div>

          <fieldset className="rounded-xs border border-catalog-line bg-catalog-paper p-4 sm:p-5">
            <legend className="px-2 font-display text-lg text-catalog-ink">
              Filtros
            </legend>
            <p className="mb-4 text-sm text-catalog-ink/60">
              Elige universidad, carrera, asignatura y profesor en ese orden;
              cada nivel acota las opciones del siguiente.
            </p>

            <AcademicSelectors
              showHeading={false}
              value={academicValue}
              onChange={handleAcademicChange}
            />

            <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Input
                label="Año"
                name="year"
                inputMode="numeric"
                maxLength={4}
                placeholder="Ej. 2026"
                value={
                  yearDraft ??
                  (filters.year !== undefined ? String(filters.year) : '')
                }
                onChange={(event) => {
                  setYearDraft(event.target.value);
                  setYearError(null);
                }}
                error={yearError ?? undefined}
                helperText={
                  yearError ? undefined : 'Se aplica al presionar Buscar.'
                }
              />
              <Select
                label="Tipo de material"
                name="type"
                value={filters.type ?? ''}
                options={typeOptions}
                onChange={(event) =>
                  update({
                    filters: {
                      ...filters,
                      type: event.target.value || undefined,
                    },
                  })
                }
              />
            </div>

            {hasFiltersToClear && (
              <div className="mt-4">
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={handleClearFilters}
                >
                  Limpiar filtros
                </Button>
              </div>
            )}
          </fieldset>
        </form>

        {hasCriteria ? (
          <SearchResults
            query={q}
            data={data}
            isLoading={isLoading}
            isFetching={isFetching}
            isError={isError}
            error={error}
            onRetry={() => void refetch()}
            onPageChange={(next) => update({ page: next })}
          />
        ) : (
          <div
            role="status"
            className="rounded-xs border border-dashed border-catalog-line bg-catalog-paperMuted px-6 py-12 text-center"
          >
            <p className="font-display text-lg text-catalog-ink">
              Escribe lo que buscas
            </p>
            <p className="mx-auto mt-1 max-w-md text-sm text-catalog-ink/60">
              También puedes empezar eligiendo filtros. Los resultados
              aparecerán aquí, con opciones de orden y páginas.
            </p>
          </div>
        )}
      </div>
    </section>
  );
}
