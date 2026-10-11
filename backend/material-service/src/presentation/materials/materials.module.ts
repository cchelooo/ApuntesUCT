import { Module } from '@nestjs/common';
import { PrismaModule } from '../../infrastructure/prisma/prisma.module';
import { MaterialsService } from '../../application/services/materials.service';
import { MaterialsController } from './materials.controller';
import { StorageModule } from '../../infrastructure/storage/storage.module';

@Module({
  imports: [PrismaModule, StorageModule],
  controllers: [MaterialsController],
  providers: [MaterialsService],
})
export class MaterialsModule {}
