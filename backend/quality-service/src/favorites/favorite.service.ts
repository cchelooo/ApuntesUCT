import { Injectable } from '@nestjs/common';
import { Prisma, Favorite } from '.prisma/quality-client';
import { PrismaService } from '../infrastructure/prisma/prisma.service';
import { FavoriteDependencies } from './favorite-dependencies';
import { fail } from './favorite-contract';
function dto(f: Favorite, available: boolean) {
  return { id: f.id, materialId: f.materialId, createdAt: f.createdAt.toISOString(), available };
}
@Injectable()
export class FavoriteService {
  constructor(
    private readonly db: PrismaService,
    private readonly dependencies: FavoriteDependencies,
  ) {}
  private async lock(tx: Prisma.TransactionClient, userId: string, materialId: string) {
    await tx.$queryRaw`SELECT 1 FROM pg_advisory_xact_lock(hashtextextended(${'favorite:' + userId + ':' + materialId},0))`;
  }
  async put(userId: string, materialId: string) {
    // Incluso un favorito ya existente debe comprobar la visibilidad actual.
    if (!(await this.dependencies.available(materialId)))
      fail(404, 'NOT_FOUND', 'Material no disponible.');
    return this.db.$transaction(
      async (tx) => {
        await this.lock(tx, userId, materialId);
        const existing = await tx.favorite.findUnique({
          where: { materialId_userId: { materialId, userId } },
        });
        if (existing) return { created: false, body: dto(existing, true) };
        const favorite = await tx.favorite.create({ data: { materialId, userId } });
        return { created: true, body: dto(favorite, true) };
      },
      { maxWait: 2000, timeout: 2500 },
    );
  }
  async remove(userId: string, materialId: string) {
    // No se consulta Material: permite eliminar referencias ocultas, eliminadas o ausentes.
    await this.db.$transaction(
      async (tx) => {
        await this.lock(tx, userId, materialId);
        await tx.favorite.deleteMany({ where: { materialId, userId } });
      },
      { maxWait: 2000, timeout: 2500 },
    );
  }
  async list(userId: string, page: number, pageSize: number) {
    const [favorites, total] = await this.db.$transaction(
      [
        this.db.favorite.findMany({
          where: { userId },
          skip: (page - 1) * pageSize,
          take: pageSize,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        }),
        this.db.favorite.count({ where: { userId } }),
      ],
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
    const items = new Array<ReturnType<typeof dto>>(favorites.length);
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), 2500);
    let next = 0;
    try {
      // Cuatro trabajadores por página y plazo global: no escanear todos los favoritos.
      await Promise.all(
        Array.from({ length: Math.min(4, favorites.length) }, async () => {
          while (!abort.signal.aborted) {
            const i = next++;
            if (i >= favorites.length) return;
            const favorite = favorites[i];
            items[i] = dto(
              favorite,
              await this.dependencies.available(favorite.materialId, abort.signal),
            );
          }
          fail(
            503,
            'DEPENDENCY_UNAVAILABLE',
            'Se agotó el plazo de comprobación de disponibilidad.',
          );
        }),
      );
      return { items, page, pageSize, total };
    } finally {
      clearTimeout(timer);
      abort.abort();
    }
  }
}
