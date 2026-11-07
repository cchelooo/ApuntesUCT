import { Module } from '@nestjs/common';
import { CheckQualityHealth } from './application/check-quality-health';
import { PersistenceHealthPort } from './application/ports/persistence-health.port';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { PrismaHealthAdapter } from './infrastructure/prisma/prisma-health.adapter';
import { HealthController } from './presentation/controllers/health.controller';

@Module({
  imports: [PrismaModule],
  controllers: [HealthController],
  providers: [
    CheckQualityHealth,
    { provide: PersistenceHealthPort, useClass: PrismaHealthAdapter },
  ],
})
export class QualityModule {}
