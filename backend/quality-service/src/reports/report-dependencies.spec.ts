import { ConfigService } from '@nestjs/config';
import { ReportDependencies } from './report-dependencies';
const id = '11111111-1111-4111-8111-111111111111';
describe('REST de dependencias de reportes', () => {
  let fetchMock: jest.SpyInstance;
  let deps: ReportDependencies;
  beforeEach(() => {
    fetchMock = jest.spyOn(global, 'fetch');
    deps = new ReportDependencies(
      new ConfigService({
        QUALITY_REPORTS_AUTH_URL: 'http://auth.test',
        QUALITY_REPORTS_MATERIAL_URL: 'http://material.test',
      }),
    );
  });
  test('sin bearer no consulta Auth', async () => {
    await expect(deps.identity()).rejects.toMatchObject({ status: 401 });
    expect(fetchMock).not.toHaveBeenCalled();
  });
  test.each([401, 403])('propaga rechazo Auth %s', async (status) => {
    fetchMock.mockResolvedValue(new Response('', { status }));
    await expect(deps.identity('Bearer token')).rejects.toMatchObject({ status });
  });
  test('caída de Auth', async () => {
    fetchMock.mockRejectedValue(Error());
    await expect(deps.identity('Bearer token')).rejects.toMatchObject({ status: 503 });
  });
  test('JSON inválido', async () => {
    fetchMock.mockResolvedValue(new Response('bad'));
    await expect(deps.identity('Bearer token')).rejects.toMatchObject({ status: 502 });
  });
  test('no confía en identidad incompleta', async () => {
    fetchMock.mockResolvedValue(Response.json({ id, role: 'ADMIN' }));
    await expect(deps.identity('Bearer token')).rejects.toMatchObject({ status: 502 });
  });
  test('material privado no se reporta', async () => {
    fetchMock.mockResolvedValue(new Response('', { status: 404 }));
    await expect(deps.publishedOwner(id)).rejects.toMatchObject({ status: 404 });
  });
  test('no acepta estado privado con HTTP 200', async () => {
    fetchMock.mockResolvedValue(Response.json({ id, uploaderId: id, status: 'PENDING_REVIEW' }));
    await expect(deps.publishedOwner(id)).rejects.toMatchObject({ status: 502 });
  });
  test('origines no configurados fallan cerrados', async () => {
    deps = new ReportDependencies(new ConfigService());
    await expect(deps.identity('Bearer token')).rejects.toMatchObject({ status: 503 });
  });
});
