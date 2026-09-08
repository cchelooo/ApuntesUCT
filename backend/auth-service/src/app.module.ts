import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import configuration from './infrastructure/config/configuration';
import { PrismaModule } from './infrastructure/prisma/prisma.module';
import { HealthModule } from './presentation/health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    PrismaModule,
    HealthModule,
  ],
})
export class AppModule {}
