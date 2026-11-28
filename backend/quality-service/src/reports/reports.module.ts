import { Module } from '@nestjs/common';
import { PrismaModule } from '../infrastructure/prisma/prisma.module';
import { ReportController } from './report.controller';
import { ReportService } from './report.service';
import { ReportDependencies } from './report-dependencies';
import { ReportGuard } from './report.guard';
@Module({
  imports: [PrismaModule],
  controllers: [ReportController],
  providers: [ReportService, ReportDependencies, ReportGuard],
})
export class ReportsModule {}
