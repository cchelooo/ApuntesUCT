import { Module } from '@nestjs/common';
import { PrismaModule } from '../infrastructure/prisma/prisma.module';
import { FavoriteController } from './favorite.controller';
import { FavoriteService } from './favorite.service';
import { FavoriteDependencies } from './favorite-dependencies';
import { FavoriteGuard } from './favorite.guard';
@Module({
  imports: [PrismaModule],
  controllers: [FavoriteController],
  providers: [FavoriteService, FavoriteDependencies, FavoriteGuard],
})
export class FavoritesModule {}
