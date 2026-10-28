import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { MaterialVersionController } from '../src/presentation/controllers/material-version.controller';
import { CreateMaterialVersion } from '../src/application/use-cases/create-material-version';
import { MaterialAuthorProvider } from '../src/infrastructure/auth/material-author.provider';
import { setupApp } from '../src/setup-app';

describe('POST /materials/:id/versions', () => {
  let app: INestApplication;
  const create = { execute: jest.fn() };
  const author = { id: '11111111-1111-4111-8111-111111111111', universityId: null };
  const path = '/api/v1/materials/22222222-2222-4222-8222-222222222222/versions';
  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [MaterialVersionController],
      providers: [
        { provide: CreateMaterialVersion, useValue: create },
        { provide: MaterialAuthorProvider, useValue: { resolve: () => author } },
      ],
    }).compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });
  beforeEach(() => {
    jest.clearAllMocks();
    create.execute.mockResolvedValue({ versionNumber: 2 });
  });
  afterAll(async () => {
    await app.close();
  });

  it('acepta un PDF válido y usa el autor del servidor', async () => {
    const pdf = Buffer.from('%PDF-1.7\nTest\n%%EOF');
    const response = await request(app.getHttpServer())
      .post(path)
      .attach('file', pdf, 'apunte.pdf')
      .expect(201);
    expect(response.body.versionNumber).toBe(2);
    expect(create.execute).toHaveBeenCalledWith(
      '22222222-2222-4222-8222-222222222222',
      author,
      expect.objectContaining({ buffer: pdf }),
    );
  });
  it('exige archivo', async () => {
    await request(app.getHttpServer()).post(path).expect(400);
    expect(create.execute).not.toHaveBeenCalled();
  });
  it('rechaza archivos vacíos', async () => {
    await request(app.getHttpServer())
      .post(path)
      .attach('file', Buffer.alloc(0), 'empty.pdf')
      .expect(400);
    expect(create.execute).not.toHaveBeenCalled();
  });
  it('rechaza contenido falso aunque se declare PDF', async () => {
    await request(app.getHttpServer())
      .post(path)
      .attach('file', Buffer.from('fake'), { filename: 'fake.pdf', contentType: 'application/pdf' })
      .expect(415);
    expect(create.execute).not.toHaveBeenCalled();
  });
  it('rechaza UUID inválido', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/materials/invalid/versions')
      .attach('file', Buffer.from('%PDF-1.7\n%%EOF'), 'file.pdf')
      .expect(400);
    expect(create.execute).not.toHaveBeenCalled();
  });
  it('rechaza archivos que superan 15 MiB', async () => {
    await request(app.getHttpServer())
      .post(path)
      .attach('file', Buffer.alloc(15 * 1024 * 1024 + 1), 'large.pdf')
      .expect(413);
    expect(create.execute).not.toHaveBeenCalled();
  });
});
