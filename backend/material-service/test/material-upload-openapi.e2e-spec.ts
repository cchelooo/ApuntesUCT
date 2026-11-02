import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { isUUID } from 'class-validator';
import request from 'supertest';
import { MaterialController } from '../src/presentation/controllers/material.controller';
import { CreateMaterial } from '../src/application/use-cases/create-material';
import { MaterialAuthorProvider } from '../src/infrastructure/auth/material-author.provider';
import { setupApp } from '../src/setup-app';

describe('Swagger del POST /materials (E2E)', () => {
  let app: INestApplication;
  const create = { execute: jest.fn() };
  const author = { resolve: jest.fn() };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [MaterialController],
      providers: [
        { provide: CreateMaterial, useValue: create },
        { provide: MaterialAuthorProvider, useValue: author },
      ],
    }).compile();
    app = moduleRef.createNestApplication();
    setupApp(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('el endpoint reutiliza el DTO con UUID de Catalog y conserva el campo de archivo', async () => {
    const { body } = await request(app.getHttpServer()).get('/api/docs-json').expect(200);
    const operation = body.paths['/api/v1/materials'].post;
    const schema = operation.requestBody.content['multipart/form-data'].schema;

    // Verifica la definición publicada por el POST, no solo el modelo del DTO.
    expect(schema.$ref).toBe('#/components/schemas/CreateMaterialDto');
    const dtoSchema = body.components.schemas.CreateMaterialDto;
    for (const field of ['subjectId', 'careerId', 'professorId']) {
      const property = dtoSchema.properties[field];
      expect(property.format).toBe('uuid');
      expect(isUUID(property.example)).toBe(true);
      expect(property.description).toContain('Catalog');
      expect(property.description).toContain('ilustrativo');
    }
    expect(dtoSchema.properties.file).toEqual(
      expect.objectContaining({ type: 'string', format: 'binary' }),
    );
    expect(dtoSchema.required).toEqual(
      expect.arrayContaining(['title', 'year', 'type', 'subjectId']),
    );
    expect(dtoSchema.required).not.toContain('careerId');
    expect(dtoSchema.required).not.toContain('professorId');
    expect(dtoSchema.required).not.toContain('file');
    expect(create.execute).not.toHaveBeenCalled();
    expect(author.resolve).not.toHaveBeenCalled();
  });
});
