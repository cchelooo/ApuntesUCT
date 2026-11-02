import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { SearchOrder, SearchQueryDto, SearchSortBy } from './search-query.dto';

describe('SearchQueryDto: contrato de parámetros', () => {
  const pipe = new ValidationPipe({ transform: true, whitelist: true });
  const validate = (value: Record<string, unknown>): Promise<SearchQueryDto> =>
    pipe.transform(value, { type: 'query', metatype: SearchQueryDto });

  it('conserva los valores predeterminados', async () => {
    expect(await validate({})).toMatchObject({
      page: 1,
      pageSize: 20,
      sortBy: SearchSortBy.CREATED_AT,
      order: SearchOrder.DESC,
    });
  });

  it('transforma números, UUID y espacios exteriores de type', async () => {
    expect(
      await validate({
        universityId: 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA',
        year: '2026',
        page: '2',
        pageSize: '5',
        type: ' APUNTE ',
        sortBy: 'title',
        order: 'asc',
      }),
    ).toMatchObject({
      universityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      year: 2026,
      page: 2,
      pageSize: 5,
      type: 'APUNTE',
      sortBy: 'title',
      order: 'asc',
    });
  });

  it.each(['universityId', 'careerId', 'subjectId', 'professorId'])(
    'rechaza UUID inválido en %s',
    async (field) => {
      await expect(validate({ [field]: 'subject-1' })).rejects.toBeInstanceOf(BadRequestException);
    },
  );

  it.each([
    { year: '1899' },
    { year: '2100' },
    { year: '' },
    { year: '2026.5' },
    { year: '2e3' },
    { year: ['2026'] },
    { type: '' },
    { type: '   ' },
    { type: ['DOCUMENT', 'LINK'] },
    { type: 'x'.repeat(101) },
    { page: '0' },
    { page: '2147483648' },
    { page: '' },
    { page: ['1'] },
    { page: '1.5' },
    { pageSize: '0' },
    { pageSize: '101' },
    { sortBy: 'rating' },
    { sortBy: 'verified' },
    { order: 'up' },
    { q: ['uno', 'dos'] },
    { q: 'x'.repeat(201) },
  ])('devuelve 400 ante parámetros inválidos: %j', async (input) => {
    await expect(validate(input)).rejects.toBeInstanceOf(BadRequestException);
  });

  it.each(['1900', '2099'])('acepta el año límite %s', async (year) => {
    expect((await validate({ year })).year).toBe(Number(year));
  });
});
