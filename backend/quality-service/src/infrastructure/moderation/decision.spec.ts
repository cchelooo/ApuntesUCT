import { decision, pageQuery } from './decision';
describe('Contrato de decisiones', () => {
  it('normaliza el motivo antes de calcular idempotencia', () =>
    expect(decision({ action: 'REJECT', expectedRevision: 1, reason: '  Incompleto  ' })).toEqual({
      action: 'REJECT',
      expectedRevision: 1,
      reason: 'Incompleto',
    }));
  it.each([
    { action: ['APPROVE'], expectedRevision: 1 },
    { action: 'REJECT', expectedRevision: 1 },
    { action: 'REJECT', expectedRevision: 1, reason: ' ' },
    { action: 'APPROVE', expectedRevision: 0 },
    { action: 'APPROVE', expectedRevision: '1' },
    { action: 'APPROVE', expectedRevision: 1.5 },
    { action: 'APPROVE', expectedRevision: 1, status: 'PUBLISHED' },
    { action: 'APPROVE', expectedRevision: 1, reason: null },
    { action: 'REJECT', expectedRevision: 1, reason: 'x'.repeat(2001) },
  ])('rechaza solicitud inválida %j', (body) => expect(() => decision(body)).toThrow());
  it.each([
    { page: ['1', '2'] },
    { page: '' },
    { pageSize: '101' },
    { page: '2147483647', pageSize: '100' },
    { unknown: 'x' },
    { status: 'WITHDRAWN' },
  ])('rechaza paginación inválida %j', (q) => expect(() => pageQuery(q)).toThrow());
});
