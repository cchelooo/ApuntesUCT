import { ConfigService } from '@nestjs/config';
import { FavoriteDependencies } from './favorite-dependencies';
const id = '11111111-1111-4111-8111-111111111111';
describe('Dependencias de favoritos', () => {
  let fetchMock: jest.SpiedFunction<typeof fetch>;
  let deps: FavoriteDependencies;
  beforeEach(() => {
    fetchMock = jest.spyOn(global, 'fetch');
    deps = new FavoriteDependencies(
      new ConfigService({
        QUALITY_FAVORITES_AUTH_URL: 'http://auth.test',
        QUALITY_FAVORITES_MATERIAL_URL: 'http://material.test',
      }),
    );
  });
  test('no consulta Auth sin bearer', async () => {
    await expect(deps.identity()).rejects.toMatchObject({ status: 401 });
    expect(fetchMock).not.toHaveBeenCalled();
  });
  test.each([401, 403])('rechazo Auth %s', async (status) => {
    fetchMock.mockResolvedValue(new Response('', { status }));
    await expect(deps.identity('Bearer token')).rejects.toMatchObject({ status });
  });
  test('identidad debe ser completa y activa', async () => {
    fetchMock.mockResolvedValue(Response.json({ id, role: 'ADMIN', active: false }));
    await expect(deps.identity('Bearer token')).rejects.toMatchObject({ status: 502 });
  });
  test('404 de Material es no disponible', async () => {
    fetchMock.mockResolvedValue(new Response('', { status: 404 }));
    await expect(deps.available(id)).resolves.toBe(false);
  });
  test('PUBLISHED autoritativo', async () => {
    fetchMock.mockResolvedValue(
      Response.json({ id, status: 'PUBLISHED', title: 'No se devuelve' }),
    );
    await expect(deps.available(id)).resolves.toBe(true);
    expect(fetchMock.mock.calls[0][1]).not.toHaveProperty('headers');
  });
  test.each([500, 502, 503])('fallo Material %s no es false', async (status) => {
    fetchMock.mockResolvedValue(new Response('', { status }));
    await expect(deps.available(id)).rejects.toMatchObject({ status: 503 });
  });
  test.each([401, 403, 302])('respuesta inesperada %s', async (status) => {
    fetchMock.mockResolvedValue(new Response('', { status }));
    await expect(deps.available(id)).rejects.toMatchObject({ status: 502 });
  });
  test.each([{ id, status: 'PENDING_REVIEW' }, { id: 'other', status: 'PUBLISHED' }, {}])(
    'payload inválido %j',
    async (v) => {
      fetchMock.mockResolvedValue(Response.json(v));
      await expect(deps.available(id)).rejects.toMatchObject({ status: 502 });
    },
  );
  test('JSON inválido', async () => {
    fetchMock.mockResolvedValue(new Response('not-json'));
    await expect(deps.available(id)).rejects.toMatchObject({ status: 502 });
  });
  test('red caída', async () => {
    fetchMock.mockRejectedValue(Error('network'));
    await expect(deps.available(id)).rejects.toMatchObject({ status: 503 });
  });
  test('config ausente falla cerrado', async () => {
    deps = new FavoriteDependencies(new ConfigService());
    await expect(deps.available(id)).rejects.toMatchObject({ status: 503 });
  });
  test('HTTP no permitido en producción', async () => {
    deps = new FavoriteDependencies(
      new ConfigService({
        NODE_ENV: 'production',
        QUALITY_FAVORITES_MATERIAL_URL: 'http://material.test',
      }),
    );
    await expect(deps.available(id)).rejects.toMatchObject({ status: 503 });
  });
});
