import { Injectable } from '@nestjs/common';
import { PersistenceHealthPort } from '../../application/ports/persistence-health.port';
import { PrismaService } from './prisma.service';

@Injectable()
export class PrismaHealthAdapter extends PersistenceHealthPort {
  constructor(private readonly prisma: PrismaService) {
    super();
  }
  async check(): Promise<void> {
    await this.prisma.$queryRaw`SELECT 1`;
  }
}
