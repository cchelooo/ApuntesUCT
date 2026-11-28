import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import type { Request } from 'express';
import { FavoriteDependencies } from './favorite-dependencies';
import type { FavoriteActor } from './favorite-contract';
export type FavoriteRequest = Request & { actor: FavoriteActor };
@Injectable()
export class FavoriteGuard implements CanActivate {
  constructor(private readonly dependencies: FavoriteDependencies) {}
  async canActivate(context: ExecutionContext) {
    const req = context.switchToHttp().getRequest<FavoriteRequest>();
    req.actor = await this.dependencies.identity(req.headers.authorization);
    return true;
  }
}
