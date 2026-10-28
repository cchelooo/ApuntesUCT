import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './presentation/controllers/health.controller';
import { SearchModule } from './search.module';

@Module({
  imports: [TerminusModule, SearchModule],
  controllers: [HealthController],
  providers: [],
})
export class AppModule {}