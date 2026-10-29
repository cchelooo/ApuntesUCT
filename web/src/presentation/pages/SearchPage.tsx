import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useSearchQuery } from '../../application/search/useSearchQuery';
import {
  DEFAULT_SEARCH_SORT,
  isSearchSort,
  type SearchSort,
} from '../../domain/search/search';
import { DEFAULT_SEARCH_PAGE_SIZE } from '../../infrastructure/search/searchApi';
import { Button } from '../components/Button';
import { Input } from '../components/Input';
import { SearchResults } from '../components/search/SearchResults';
import { SearchSortSelect } from '../components/search/SearchSortSelect';

function parsePage(value: string | null): number {
  const page = Number(value);
  return Number.isInteger(page) && page >= 1 ? page : 1;
}

export function SearchPage() {
  const [params, setParams] = useSearchParams();
  const q = (params.get('q') ?? '').trim();
  const sortParam = params.get('sort');
  const sort: SearchSort = isSearchSort(sortParam)
    ? sortParam
    : DEFAULT_SEARCH_SORT;
  const page = parsePage(params.get('page'));

  const [draft, setDraft] = useState(q);

  const { data, isLoading, isFetching, isError, error, refetch } =
    useSearchQuery({ q, sort, page, pageSize: DEFAULT_SEARCH_PAGE_SIZE });

  function update(next: { q?: string; sort?: SearchSort; page?: number }) {
    const merged = {
      q: next.q ?? q,
      sort: next.sort ?? sort,
      page: next.page ?? 1,
    };
    const nextParams = new URLSearchParams();
    if (merged.q) nextParams.set('q', merged.q);
    nextParams.set('sort', merged.sort);
    if (merged.page > 1) nextParams.set('page', String(merged.page));
    setParams(nextParams);
  }

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
          className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end"
          onSubmit={(event) => {
            event.preventDefault();
            update({ q: draft.trim(), page: 1 });
          }}
        >
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
            onChange={(next) => update({ sort: next, page: 1 })}
          />
          <Button type="submit" className="min-h-10">
            Buscar
          </Button>
        </form>

        {q ? (
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
              Los resultados aparecerán aquí, con opciones de orden y páginas.
            </p>
          </div>
        )}
      </div>
    </section>
  );
}
