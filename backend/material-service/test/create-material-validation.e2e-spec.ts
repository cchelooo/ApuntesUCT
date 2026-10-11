import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { MaterialController } from '../src/presentation/controllers/material.controller';
import { CreateMaterial } from '../src/application/use-cases/create-material';
import { ObjectStorage } from '../src/application/ports/object-storage.port';
import { PrismaService } from '../src/infrastructure/prisma/prisma.service';
import { MaterialAuthorProvider } from '../src/infrastructure/auth/material-author.provider';
import { setupApp } from '../src/setup-app';

describe('POST /materials: campos obligatorios con contenido', () => {
  let app: INestApplication;
  const prisma = { materialType: { findFirst: jest.fn() }, material: { create: jest.fn() } };
  const storage = { save: jest.fn(), remove: jest.fn() };
  const fields = {
    title: 'Guía de Álgebra Lineal',
    subjectId: 'SUBJ-102',
    year: '2026',
    type: 'LINK',
    externalLink: 'https://example.com/material',
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [MaterialController],
      providers: [
        CreateMaterial,
        { provide: PrismaService, useValue: prisma },
        { provide: ObjectStorage, useValue: storage },
        {
          provide: MaterialAuthorProvider,
          useValue: {
            resolve: () => ({ id: '11111111-1111-4111-8111-111111111111', universityId: null }),
          },
        },
      ],
    }).compile();
    app = module.createNestApplication();
    setupApp(app);
    await app.init();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.materialType.findFirst.mockResolvedValue({ id: 'type-id' });
    prisma.material.create.mockImplementation(({ data }) =>
      Promise.resolve({ ...data, id: 'material-id', createdAt: new Date() }),
    );
  });

  afterAll(async () => {
    await app.close();
  });

  for (const field of ['title', 'subjectId']) {
    it.each(['', ' ', '   ', '\t', '\r\n', '\u00a0\u2003'])(
      'rechaza ' + field + ' compuesto solo por blancos: %j',
      async (value) => {
        const response = await request(app.getHttpServer())
          .post('/api/v1/materials')
          .field({ ...fields, [field]: value })
          .expect(400);
        expect(response.body.message).toEqual(
          expect.arrayContaining([expect.stringContaining(field)]),
        );
        expect(prisma.materialType.findFirst).not.toHaveBeenCalled();
        expect(prisma.material.create).not.toHaveBeenCalled();
        expect(storage.save).not.toHaveBeenCalled();
      },
    );
  }

  it('conserva un título válido con espacios entre palabras y una asignatura válida', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/v1/materials')
      .field(fields)
      .expect(201);
    expect(response.body.data.title).toBe(fields.title);
    expect(prisma.material.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ title: fields.title, subjectId: fields.subjectId }),
    });
  });
});
