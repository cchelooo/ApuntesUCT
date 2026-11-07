import { CheckQualityHealth } from './check-quality-health';

describe('CheckQualityHealth', () => {
  it('informa conexión disponible', async () => {
    const persistence = { check: jest.fn().mockResolvedValue(undefined) };
    const result = await new CheckQualityHealth(persistence).execute();
    expect(result).toEqual({ status: 'ok', service: 'quality-service', database: 'up' });
    expect(persistence.check).toHaveBeenCalledTimes(1);
  });
  it('oculta detalles de conexión y devuelve estado down', async () => {
    const persistence = { check: jest.fn().mockRejectedValue(new Error('private credentials')) };
    expect(await new CheckQualityHealth(persistence).execute()).toEqual({
      status: 'error',
      service: 'quality-service',
      database: 'down',
    });
  });
});
