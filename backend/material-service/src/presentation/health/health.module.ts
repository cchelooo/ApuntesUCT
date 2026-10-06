import { Module } from '@nestjs/common';
import { HealthService } from '../../application/health/health.service';
import { HealthController } from './health.controller';

@Module({
  controllers: [HealthController],
  providers: [HealthService],
})
export class HealthModule {}
