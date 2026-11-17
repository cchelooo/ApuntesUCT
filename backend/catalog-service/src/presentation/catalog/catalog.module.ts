import { CatalogAuthorizationGuard } from '../../infrastructure/auth/catalog-authorization.guard';
import { AccessTokenVerifier } from '../../infrastructure/auth/access-token.verifier';
import { Module } from '@nestjs/common';
import { CatalogController } from './catalog.controller';
import { CatalogService } from '../../application/services/catalog.service';

@Module({
  controllers: [CatalogController],
  providers: [CatalogService, AccessTokenVerifier, CatalogAuthorizationGuard],
  exports: [CatalogService],
})
export class CatalogModule {}
