import { FavoriteService } from './favorite.service';
import { FavoriteDependencies } from './favorite-dependencies';
import { PrismaService } from '../infrastructure/prisma/prisma.service';
const fixtures = Array.from({ length: 11 }, (_, i) => ({
  id: 'favorite-' + i,
  materialId: 'material-' + i,
  userId: 'user',
  createdAt: new Date(0),
}));
describe('Disponibilidad de la página de favoritos', () => {
  function service(available: jest.Mock, rows = fixtures) {
    const findMany = jest.fn().mockReturnValue(rows),
      count = jest.fn().mockReturnValue(50);
    const db = {
      $transaction: jest.fn().mockResolvedValue([rows, 50]),
      favorite: { findMany, count },
    };
    return {
      instance: new FavoriteService(
        db as unknown as PrismaService,
        { available } as unknown as FavoriteDependencies,
      ),
      findMany,
      count,
    };
  }
  test('concurrencia máxima cuatro, orden conservado y sólo página solicitada', async () => {
    let active = 0,
      max = 0;
    const available = jest.fn(async () => {
      active++;
      max = Math.max(max, active);
      await new Promise((r) => setTimeout(r, 2));
      active--;
      return true;
    });
    const { instance, findMany } = service(available);
    const result = await instance.list('user', 2, 11);
    expect(max).toBe(4);
    expect(available).toHaveBeenCalledTimes(11);
    expect(findMany).toHaveBeenCalledWith({
      where: { userId: 'user' },
      skip: 11,
      take: 11,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
    expect(result.total).toBe(50);
    expect(result.items.map((x) => x.id)).toEqual(fixtures.map((x) => x.id));
    expect(result.items[0]).not.toHaveProperty('userId');
  });
  test('página vacía no consulta Material y conserva total', async () => {
    const available = jest.fn();
    const { instance } = service(available, []);
    expect(await instance.list('user', 100, 20)).toEqual({
      items: [],
      page: 100,
      pageSize: 20,
      total: 50,
    });
    expect(available).not.toHaveBeenCalled();
  });
  test('error de un recurso rechaza la página; nunca fabrica available=false', async () => {
    const available = jest.fn().mockRejectedValue(Error('down'));
    const { instance } = service(available);
    await expect(instance.list('user', 1, 20)).rejects.toThrow('down');
  });
  test('plazo global cancela comprobaciones lentas', async () => {
    jest.useFakeTimers();
    try {
      const available = jest.fn(
        (_id: string, signal: AbortSignal) =>
          new Promise<boolean>((_resolve, reject) =>
            signal.addEventListener('abort', () => reject(Error('deadline')), { once: true }),
          ),
      );
      const { instance } = service(available);
      const pending = instance.list('user', 1, 20);
      const assertion = expect(pending).rejects.toThrow('deadline');
      await jest.advanceTimersByTimeAsync(2501);
      await assertion;
    } finally {
      jest.useRealTimers();
    }
  });
});
