import { Test, TestingModule } from '@nestjs/testing';
import { HealthController } from './health.controller';

describe('HealthController', () => {
  let controller: HealthController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
    }).compile();

    controller = module.get<HealthController>(HealthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('returns the gateway status with the current UTC timestamp on each check', () => {
    jest.useFakeTimers();

    try {
      jest.setSystemTime(new Date('2026-09-28T12:00:00.000Z'));
      expect(controller.check()).toEqual({
        status: 'ok',
        service: 'API Gateway',
        timestamp: '2026-09-28T12:00:00.000Z',
      });

      jest.advanceTimersByTime(1000);
      expect(controller.check().timestamp).toBe('2026-09-28T12:00:01.000Z');
    } finally {
      jest.useRealTimers();
    }
  });
});
