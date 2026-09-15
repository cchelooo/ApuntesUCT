import { PrismaService } from './prisma.service';

describe('PrismaService', () => {
  it('debe propagar los errores de conexión para impedir un inicio sin base de datos', async () => {
    const service = new PrismaService();
    const error = new Error('PostgreSQL no disponible');
    jest.spyOn(service, '$connect').mockRejectedValue(error);

    await expect(service.onModuleInit()).rejects.toBe(error);
  });
});
