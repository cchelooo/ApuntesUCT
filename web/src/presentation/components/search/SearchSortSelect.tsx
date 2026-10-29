import {
  SEARCH_SORT_OPTIONS,
  isSearchSort,
  type SearchSort,
} from '../../../domain/search/search';
import { Select } from '../Select';

interface SearchSortSelectProps {
  value: SearchSort;
  disabled?: boolean;
  onChange: (sort: SearchSort) => void;
}

export function SearchSortSelect({
  value,
  disabled = false,
  onChange,
}: SearchSortSelectProps) {
  return (
    <Select
      label="Ordenar por"
      name="sort"
      fullWidth={false}
      containerClassName="min-w-56"
      value={value}
      disabled={disabled}
      options={SEARCH_SORT_OPTIONS.map((option) => ({ ...option }))}
      onChange={(event) => {
        const next = event.target.value;
        if (isSearchSort(next)) onChange(next);
      }}
    />
  );
}
