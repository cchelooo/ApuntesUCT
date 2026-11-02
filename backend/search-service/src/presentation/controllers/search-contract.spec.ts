import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { DocumentBuilder, OpenAPIObject, SwaggerModule } from '@nestjs/swagger';
import { SearchService } from '../../application/services/search.service';
import { SearchController } from './search.controller';

describe('Search: documentación pública de filtros', () => {
  let app: INestApplication;
  let document: OpenAPIObject;
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [SearchController],
      providers: [{ provide: SearchService, useValue: { search: jest.fn() } }],
    }).compile();
    app = module.createNestApplication();
    await app.init();
    document = SwaggerModule.createDocument(app, new DocumentBuilder().build());
  });
  afterAll(async () => {
    await app.close();
  });

  it('publica los once parámetros desde el DTO sin duplicaciones', () => {
    const operation = document.paths['/api/v1/search'].get!;
    const parameters = (operation.parameters ?? []).flatMap((parameter) => 
      '$ref' in parameter ? [] : [parameter],
    );
    expect(parameters.map((parameter) => parameter.name).sort()).toEqual(
      [
        'q',
        'universityId',
        'careerId',
        'subjectId',
        'professorId',
        'year',
        'type',
        'sortBy',
        'order',
        'page',
        'pageSize',
      ].sort(),
    );
    expect(parameters.every((parameter) => parameter.in === 'query' && !parameter.required)).toBe(
      true,
    );
  });

  it('documenta cascada, año/tipo independientes, límite ampliado y errores', () => {
    const operation = document.paths['/api/v1/search'].get!;
    expect(operation.description).toContain('careerId requiere universityId');
    expect(operation.description).toContain('year y type son independientes');
    expect(operation.description).toContain('texto, filtros o un orden distinto');
    expect(operation.description).toContain('10.000');
    expect(operation.description).toContain('id DESC');
    expect(operation.security ?? []).toEqual([]);
    expect(Object.keys(operation.responses)).toEqual(
      expect.arrayContaining(['200', '400', '502', '503']),
    );
    expect(document.components?.schemas).toHaveProperty('SearchResponseDto');
  });
});
