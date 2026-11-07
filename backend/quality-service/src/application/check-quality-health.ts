import { Injectable } from '@nestjs/common';
import { PersistenceHealthPort } from './ports/persistence-health.port';

export interface QualityHealth {
  status: 'ok' | 'error';
  service: 'quality-service';
  database: 'up' | 'down';
}

@Injectable()
export class CheckQualityHealth {
  constructor(private readonly persistence: PersistenceHealthPort) {}
  async execute(): Promise<QualityHealth> {
    try {
      await this.persistence.check();
      return { status: 'ok', service: 'quality-service', database: 'up' };
    } catch {
      return { status: 'error', service: 'quality-service', database: 'down' };
    }
  }
}
