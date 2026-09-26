import { TestingModule, Test } from '@nestjs/testing';
import { HealthService } from '../../application/health/health.service';
import { PrismaService } from '../../infrastructure/prisma/prisma.service';
import { HealthController } from './health.controller';

describe('HealthController', () => {
  let moduleRef: TestingModule;
  let controller: HealthController;
  let prisma: PrismaService;

  beforeEach(async () => {
    moduleRef = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        HealthService,
        { provide: PrismaService, useValue: { $queryRaw: jest.fn() } },
      ],
    }).compile();

    controller = moduleRef.get(HealthController);
    prisma = moduleRef.get(PrismaService);
  });

  it('debe estar definido', () => {
    expect(controller).toBeDefined();
  });

  it('debe retornar ok y connected cuando PostgreSQL responde', async () => {
    prisma.$queryRaw = jest.fn().mockResolvedValue([{ '?column?': 1 }]);
    const res = { status: jest.fn().mockReturnThis() };

    const result = await controller.check(res as never);

    expect(result.status).toBe('ok');
    expect(result.service).toBe('auth-service');
    expect(result.database).toBe('connected');
    expect(result.timestamp).toBeDefined();
    expect(res.status).not.toHaveBeenCalled();
  });

  it('debe retornar unavailable y disconnected con 503 cuando PostgreSQL no responde', async () => {
    prisma.$queryRaw = jest
      .fn()
      .mockRejectedValue(new Error('sin conexión a la base de datos'));
    const res = { status: jest.fn().mockReturnThis() };

    const result = await controller.check(res as never);

    expect(result.status).toBe('unavailable');
    expect(result.service).toBe('auth-service');
    expect(result.database).toBe('disconnected');
    expect(result.timestamp).toBeDefined();
    expect(res.status).toHaveBeenCalledWith(503);
  });
});