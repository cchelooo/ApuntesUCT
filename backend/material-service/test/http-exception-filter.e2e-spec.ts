import { BadRequestException, Controller, Get, INestApplication, Param } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { setupApp } from '../src/setup-app';

// Controlador exclusivo de prueba: no se registra en la aplicación de producción.
@Controller('filter-contract')
class ErrorProbeController {
  @Get(':field')
  fail(@Param('field') field: string): never {
    if (field === 'unexpected') throw new Error('detalle interno privado');
    if (field === 'validation') {
      throw new BadRequestException(['title es obligatorio', 'year no es válido']);
    }
    if (field === 'plain') throw new BadRequestException('Petición inválida.');
    throw new BadRequestException({
      statusCode: 400,
      error: 'Bad Request',
      message: 'Referencia académica inválida.',
      field,
    });
  }
}

describe('HttpExceptionFilter con setupApp real (E2E)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [ErrorProbeController],
    }).compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it.each(['subjectId', 'careerId', 'professorId', 'universityId'])(
    'conserva field=%s en la respuesta HTTP real',
    async (field) => {
      const path = `/api/v1/filter-contract/${field}`;
      const { body } = await request(app.getHttpServer()).get(path).expect(400);
      expect(body).toEqual({
        statusCode: 400,
        error: 'Bad Request',
        message: 'Referencia académica inválida.',
        field,
        timestamp: expect.any(String),
        path,
      });
      expect(Number.isNaN(Date.parse(body.timestamp))).toBe(false);
    },
  );

  it('conserva los mensajes de validación como arreglo', async () => {
    const { body } = await request(app.getHttpServer())
      .get('/api/v1/filter-contract/validation')
      .expect(400);
    expect(body.message).toEqual(['title es obligatorio', 'year no es válido']);
    expect(body).not.toHaveProperty('field');
    expect(body).toHaveProperty('timestamp');
    expect(body.path).toBe('/api/v1/filter-contract/validation');
  });

  it('conserva mensajes de texto sin añadir un campo académico', async () => {
    const { body } = await request(app.getHttpServer())
      .get('/api/v1/filter-contract/plain')
      .expect(400);
    expect(body.message).toBe('Petición inválida.');
    expect(body).not.toHaveProperty('field');
  });

  it('mantiene la respuesta genérica para errores inesperados', async () => {
    const { body } = await request(app.getHttpServer())
      .get('/api/v1/filter-contract/unexpected')
      .expect(500);
    expect(body.statusCode).toBe(500);
    expect(body.error).toBe('Internal Server Error');
    expect(body.message).toBe('Internal server error');
    expect(body).not.toHaveProperty('field');
    expect(JSON.stringify(body)).not.toContain('detalle interno privado');
  });
});
