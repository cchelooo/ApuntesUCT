import { Module } from '@nestjs/common';
import { PrismaModule } from '../../infrastructure/prisma/prisma.module';
import { MaterialsService } from '../../application/services/materials.service';
import { MaterialsController } from './materials.controller';
import { StorageModule } from '../../infrastructure/storage/storage.module';

import { MaterialController } from '../controllers/material.controller';
import { CreateMaterial } from '../../application/use-cases/create-material';
import { MaterialAuthorProvider } from '../../infrastructure/auth/material-author.provider';

@Module({
  imports: [PrismaModule, StorageModule],
  controllers: [MaterialsController, MaterialController],
  providers: [MaterialsService, CreateMaterial, MaterialAuthorProvider],
})
export class MaterialsModule {}
