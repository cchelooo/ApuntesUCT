import { MaterialPreviewController } from './material-preview.controller';
import { MaterialAdminController } from './material-admin.controller';
import { MaterialModeratorGuard } from '../../infrastructure/auth/material-moderator.guard';
import { CreateMaterialVersion } from '../../application/use-cases/create-material-version';
import { MaterialVersionController } from '../controllers/material-version.controller';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from '../../infrastructure/prisma/prisma.module';
import { MaterialsService } from '../../application/services/materials.service';
import { MaterialsController } from './materials.controller';
import { StorageModule } from '../../infrastructure/storage/storage.module';
import { MaterialController } from '../controllers/material.controller';
import { CreateMaterial } from '../../application/use-cases/create-material';
import { MaterialAuthorProvider } from '../../infrastructure/auth/material-author.provider';
import { AccessTokenVerifier } from '../../infrastructure/auth/access-token.verifier';
import { CatalogPort } from '../../application/ports/catalog.port';
import { CatalogHttpAdapter } from '../../infrastructure/catalog/catalog-http.adapter';

@Module({
  imports: [ConfigModule, PrismaModule, StorageModule],
  controllers: [
    MaterialAdminController,
    MaterialPreviewController,
    MaterialsController,
    MaterialController,
    MaterialVersionController,
  ],
  providers: [
    MaterialsService,
    MaterialModeratorGuard,
    CreateMaterial,
    CreateMaterialVersion,
    AccessTokenVerifier,
    MaterialAuthorProvider,
    { provide: CatalogPort, useClass: CatalogHttpAdapter },
  ],
})
export class MaterialsModule {}
