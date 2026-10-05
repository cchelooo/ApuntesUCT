import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import configuration from './infrastructure/config/configuration';
import { HealthModule } from './presentation/health/health.module';
import { MaterialController } from './presentation/controllers/material.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    PrismaModule,
    HealthModule,
  ],
  controllers: [MaterialController],
})
export class AppModule {}