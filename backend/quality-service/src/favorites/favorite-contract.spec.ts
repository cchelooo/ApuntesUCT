import { materialId, pageInput, noPayload } from './favorite-contract';
describe('Contrato de favoritos', () => {
  test('UUID normalizado', () =>
    expect(materialId('AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA')).toBe(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    ));
  test.each([null, undefined, 'x', 12, []])('UUID inválido %j', (v) =>
    expect(() => materialId(v)).toThrow(),
  );
  test('defaults', () => expect(pageInput({})).toEqual({ page: 1, pageSize: 20 }));
  test('límites válidos', () =>
    expect(pageInput({ page: '2147483647', pageSize: '1' })).toEqual({
      page: 2147483647,
      pageSize: 1,
    }));
  test.each([
    { page: '' },
    { page: '0' },
    { page: '1.5' },
    { page: ['1', '2'] },
    { page: '2147483648' },
    { pageSize: '101' },
    { pageSize: '-1' },
    { pageSize: ['10', '20'] },
    { page: '2147483647', pageSize: '100' },
    { userId: 'spoof' },
    { sort: 'id' },
  ])('query inválida %j', (v) => expect(() => pageInput(v)).toThrow());
  test('sin cuerpo', () => expect(() => noPayload(undefined, {}, '0')).not.toThrow());
  test.each([{ userId: 'spoof' }, { materialId: 'spoof' }, [], 1, 'text'])(
    'cuerpo no permitido %j',
    (v) => expect(() => noPayload(v, {})).toThrow(),
  );
  test('rechaza incluso objeto vacío enviado como cuerpo', () =>
    expect(() => noPayload({}, {}, '2')).toThrow());
  test('rechaza cuerpo chunked', () =>
    expect(() => noPayload({}, {}, undefined, 'chunked')).toThrow());
  test('rechaza query de escritura', () =>
    expect(() => noPayload(undefined, { userId: 'spoof' })).toThrow());
});
