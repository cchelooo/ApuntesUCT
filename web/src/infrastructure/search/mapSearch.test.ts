import { describe, expect, it } from 'vitest';
import { mapRawSearchPage } from './mapSearch';

const requested = { page: 1, pageSize: 20 };

describe('mapRawSearchPage', () => {
  it('conserva results[].id de Search como id de la tarjeta', () => {
    const page = mapRawSearchPage(
      {
        results: [
          {
            id: 'real-uuid',
            title: 'Certamen 1',
            academicYear: 2026,
            materialType: 'EXAM',
            subjectId: 's-1',
          },
        ],
        page: 1,
        pageSize: 20,
        total: 1,
      },
      requested
    );
    expect(page.items[0]).toMatchObject({
      id: 'real-uuid',
      title: 'Certamen 1',
      year: 2026,
      type: 'EXAM',
      subjectId: 's-1',
    });
  });

  it('descarta resultados sin id válido', () => {
    const page = mapRawSearchPage(
      {
        items: [
          { title: 'sin id' },
          { id: '   ', title: 'id vacío' },
          { materialId: 'antiguo', title: 'contrato anterior' },
          { id: 'ok' },
        ] as never,
      },
      requested
    );
    expect(page.items.map((item) => item.id)).toEqual(['ok']);
  });

  it('acepta el stub actual (results vacío) y calcula totalPages', () => {
    const stub = mapRawSearchPage({ results: [], total: 0 }, requested);
    expect(stub).toMatchObject({ items: [], total: 0, totalPages: 1 });

    const paged = mapRawSearchPage(
      { items: [{ id: 'a' }], page: 2, pageSize: 10, total: 25 },
      requested
    );
    expect(paged).toMatchObject({ page: 2, pageSize: 10, totalPages: 3 });
  });
});
