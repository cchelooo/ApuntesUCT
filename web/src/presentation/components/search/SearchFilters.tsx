import {
  SEARCH_TYPE_OPTIONS,
  hasActiveSearchFilters,
  type SearchFilters as SearchFiltersValue,
} from '../../../domain/search/search';
import { AcademicSelectors } from '../catalog/AcademicSelectors';
import { Button } from '../Button';
import { Input } from '../Input';
import { Select } from '../Select';

interface SearchFiltersProps {
  value: SearchFiltersValue;
  yearDraft: string;
  yearError?: string;
  onYearDraftChange: (year: string) => void;
  onChange: (filters: SearchFiltersValue) => void;
  onClear: () => void;
}

const TYPE_OPTIONS = [
  { value: '', label: 'Todos los tipos' },
  ...SEARCH_TYPE_OPTIONS.map((option) => ({ ...option })),
];

export function SearchFilters({
  value,
  yearDraft,
  yearError,
  onYearDraftChange,
  onChange,
  onClear,
}: SearchFiltersProps) {
  const canClear = hasActiveSearchFilters(value) || yearDraft !== '';

  return (
    <fieldset className="rounded-xs border border-catalog-line bg-catalog-paper p-4">
      <legend className="px-1 font-display text-sm text-catalog-ink">
        Filtros
      </legend>

      <AcademicSelectors
        showHeading={false}
        value={{
          universityId: value.universityId,
          careerId: value.careerId,
          subjectId: value.subjectId,
          professorId: value.professorId,
        }}
        onChange={(selection) => onChange({ ...value, ...selection })}
      />

      <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Input
          label="Año"
          name="year"
          inputMode="numeric"
          maxLength={4}
          placeholder="Ej. 2026"
          value={yearDraft}
          error={yearError}
          onChange={(event) => onYearDraftChange(event.target.value)}
        />
        <Select
          label="Tipo de material"
          name="type"
          value={value.type}
          options={TYPE_OPTIONS}
          onChange={(event) => onChange({ ...value, type: event.target.value })}
        />
      </div>

      {canClear && (
        <div className="mt-4 flex justify-end">
          <Button type="button" variant="ghost" size="sm" onClick={onClear}>
            Limpiar filtros
          </Button>
        </div>
      )}
    </fieldset>
  );
}
