import { createInput, updateInput, pageInput, uuid, moderator } from './report-contract';
const time = '2026-11-27T12:00:00.123Z';
describe('Contrato de reportes', () => {
  test.each([
    'COPYRIGHT',
    'INAPPROPRIATE_CONTENT',
    'INCORRECT_INFORMATION',
    'BROKEN_RESOURCE',
    'OTHER',
  ])('acepta %s', (reason) =>
    expect(createInput({ reason, details: ' texto ' })).toEqual({ reason, details: 'texto' }),
  );
  test.each([
    null,
    [],
    {},
    { reason: 'UNKNOWN' },
    { reason: 'OTHER' },
    { reason: 'OTHER', details: '  ' },
    { reason: 'COPYRIGHT', userId: 'spoof' },
    { reason: 'COPYRIGHT', details: 4 },
    { reason: 'COPYRIGHT', details: 'x'.repeat(2001) },
  ])('rechaza creación inválida %j', (v) => expect(() => createInput(v)).toThrow());
  test('normaliza ausencia/null para idempotencia', () =>
    expect(createInput({ reason: 'COPYRIGHT' })).toEqual(
      createInput({ reason: 'COPYRIGHT', details: null }),
    ));
  test.each(['RESOLVED', 'DISMISSED'])('exige nota para %s', (status) => {
    expect(() => updateInput({ status, expectedUpdatedAt: time })).toThrow();
    expect(
      updateInput({ status, expectedUpdatedAt: time, resolutionNote: ' Hecho ' }),
    ).toMatchObject({ resolutionNote: 'Hecho' });
  });
  test.each([
    {},
    [],
    { status: 'OPEN', expectedUpdatedAt: time },
    { status: 'IN_REVIEW', expectedUpdatedAt: '2026-11-27' },
    { status: 'IN_REVIEW', expectedUpdatedAt: '2026-02-30T12:00:00Z' },
    { status: 'IN_REVIEW', expectedUpdatedAt: time, actorId: 'spoof' },
  ])('rechaza tratamiento inválido %j', (v) => expect(() => updateInput(v)).toThrow());
  test('normaliza instante con zona', () =>
    expect(
      updateInput({ status: 'IN_REVIEW', expectedUpdatedAt: '2026-11-27T09:00:00.123-03:00' })
        .expectedUpdatedAt,
    ).toBe(time));
  test.each([
    { page: '' },
    { page: ['1', '2'] },
    { page: '1.5' },
    { pageSize: '101' },
    { page: '2147483647', pageSize: '100' },
    { status: 'OPEN' },
    { sort: 'id' },
  ])('rechaza query %j', (v) => expect(() => pageInput(v)).toThrow());
  test('defaults y filtros de moderación', () => {
    expect(pageInput({})).toEqual({ page: 1, pageSize: 20, status: undefined });
    expect(pageInput({ status: 'OPEN' }, true).status).toBe('OPEN');
  });
  test('UUID inválido', () => expect(() => uuid('x')).toThrow());
  test('rol administrativo', () => {
    expect(() => moderator({ id: 'x', role: 'STUDENT' })).toThrow();
    expect(() => moderator({ id: 'x', role: 'ADMIN' })).not.toThrow();
  });
});

test.each([null, '', '  ', 42])('resolutionNote presente inválida: %j', (resolutionNote) => {
  expect(() =>
    updateInput({ status: 'IN_REVIEW', expectedUpdatedAt: time, resolutionNote }),
  ).toThrow();
});
