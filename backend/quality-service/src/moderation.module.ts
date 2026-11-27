import { Module } from '@nestjs/common';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { ModerationController } from './presentation/controllers/moderation.controller';
import { ModerationService } from './application/moderation.service';
import { ModerationWorker } from './application/moderation-worker';
import { MaterialClient } from './infrastructure/moderation/material-client';
import { QualityUserGuard } from './infrastructure/moderation/quality-user.guard';
@Module({
  imports: [PrismaModule],
  controllers: [ModerationController],
  providers: [ModerationService, ModerationWorker, MaterialClient, QualityUserGuard],
})
export class ModerationModule {}
