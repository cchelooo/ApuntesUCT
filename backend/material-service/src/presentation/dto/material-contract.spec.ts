import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { DocumentBuilder, OpenAPIObject, SwaggerModule } from '@nestjs/swagger';
import type {
  ReferenceObject,
  SchemaObject,
} from '@nestjs/swagger/dist/interfaces/open-api-spec.interface';
import { MaterialController } from '../controllers/material.controller';
import { MaterialsController } from '../materials/materials.controller';
import { MaterialsService } from '../../application/services/materials.service';
import { CreateMaterialDto } from './create-material.dto';
import { CreateMaterial } from '../../application/use-cases/create-material';
import { MaterialAuthorProvider } from '../../infrastructure/auth/material-author.provider';

describe('Contrato OpenAPI de materiales', () => {
  let app: INestApplication;
  let document: OpenAPIObject;

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [MaterialController, MaterialsController],
      providers: [
        { provide: MaterialsService, useValue: { list: jest.fn() } },
        { provide: CreateMaterial, useValue: { execute: jest.fn() } },
        { provide: MaterialAuthorProvider, useValue: { resolve: jest.fn() } },
      ],
    }).compile();
    app = module.createNestApplication();
    app.setGlobalPrefix('api/v1');
    await app.init();
    document = SwaggerModule.createDocument(app, new DocumentBuilder().build(), {
      extraModels: [CreateMaterialDto],
    });
  });

  afterAll(async () => {
    await app.close();
  });

  function schema(name: string): SchemaObject {
    return document.components!.schemas![name] as SchemaObject;
  }

  function multipartSchema(): SchemaObject {
    const post = document.paths['/api/v1/materials'].post!;
    const body = post.requestBody as {
      content: Record<string, { schema: SchemaObject | ReferenceObject }>;
    };
    const multipart = body.content['multipart/form-data'].schema;

    // El POST debe reutilizar el DTO, no volver a publicar un esquema manual.
    expect(multipart).toMatchObject({
      $ref: '#/components/schemas/CreateMaterialDto',
    });

    // Las propiedades están en el modelo al que apunta la referencia.
    return schema('CreateMaterialDto');
  }

  it.each(['description', 'careerId', 'professorId', 'fileUrl', 'mimeType', 'externalLink'])(
    'publica %s como string nullable en la respuesta',
    (field) => {
      expect(schema('MaterialDataDto').properties![field]).toMatchObject({
        type: 'string',
        nullable: true,
      });
    },
  );

  it('publica fileSize como number nullable', () => {
    expect(schema('MaterialDataDto').properties!.fileSize).toMatchObject({
      type: 'number',
      nullable: true,
    });
  });

  it('documenta solo PENDING_REVIEW al crear y conserva PUBLISHED en el listado', async () => {
    expect(schema('MaterialDataDto').properties!.status).toMatchObject({
      enum: ['PENDING_REVIEW'],
    });
    expect(schema('MaterialSummaryDto').properties!.status).toMatchObject({ enum: ['PUBLISHED'] });
  });

  it('explica la relación de type con el listado en el multipart publicado y en los DTOs', () => {
    const multipart = multipartSchema();
    for (const property of [
      multipart.properties!.type,
      schema('CreateMaterialDto').properties!.type,
      schema('MaterialDataDto').properties!.type,
    ]) {
      const description = (property as SchemaObject).description;
      expect(description).toContain('MaterialType.name');
      expect(description).toContain('materialTypeId');
      expect(description).toContain('GET /materials');
      expect(description).toContain('activos');
    }
    expect(schema('MaterialSummaryDto').properties).toHaveProperty('materialTypeId');
    expect(schema('MaterialSummaryDto').properties).toHaveProperty('materialType');
  });

  it('expone los cinco MIME exactos en la operación y en el archivo multipart', () => {
    const post = document.paths['/api/v1/materials'].post!;
    const file = multipartSchema().properties!.file as SchemaObject;
    expect(file).toMatchObject({ type: 'string', format: 'binary' });
    for (const mime of [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    ]) {
      expect(post.description).toContain(mime);
      expect(file.description).toContain(mime);
      expect((schema('CreateMaterialDto').properties!.file as SchemaObject).description).toContain(
        mime,
      );
    }
  });
});
