import { Test } from '@nestjs/testing';
import { CatalogPort } from '../../application/ports/catalog.port';
import { MaterialPort } from '../../application/ports/material.port';
import { SearchModule } from '../../search.module';
import { setupSwagger } from '../../setup-swagger';

interface DocumentedParameter {
  name: string;
  in?: string;
  required?: boolean;
  schema?: Record<string, unknown>;
}

interface DocumentedResponse {
  content?: {
    'application/json'?: {
      schema?: Record<string, unknown>;
    };
  };
}

describe('Search Swagger', () => {
  it('documenta los parámetros de consulta, la paginación y los errores', async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [SearchModule],
    })
      .overrideProvider(CatalogPort)
      .useValue({ getAcademicContext: async () => [] })
      .overrideProvider(MaterialPort)
      .useValue({
        findCandidates: async () => ({
          items: [],
          page: 1,
          pageSize: 20,
          total: 0,
        }),
      })
      .compile();

    const app = moduleRef.createNestApplication();
    await app.init();

    try {
      const document: any = setupSwagger(app);
      const operation = document.paths['/api/v1/search']?.get;
      const parameters = (operation?.parameters ??
        []) as unknown as DocumentedParameter[];
      const responses = (operation?.responses ??
        {}) as unknown as Record<string, DocumentedResponse>;

      expect(operation).toBeDefined();
      expect(parameters.map((parameter) => parameter.name).sort()).toEqual([
        'careerId',
        'order',
        'page',
        'pageSize',
        'professorId',
        'q',
        'sortBy',
        'subjectId',
        'type',
        'universityId',
        'year',
      ]);

      const byName = new Map(
        parameters.map((parameter) => [parameter.name, parameter]),
      );
      expect(byName.get('page')).toMatchObject({
        in: 'query',
        required: false,
        schema: {
          type: 'number',
          default: 1,
          minimum: 1,
          maximum: 2147483647,
        },
      });
      expect(byName.get('pageSize')).toMatchObject({
        in: 'query',
        required: false,
        schema: {
          type: 'number',
          default: 20,
          minimum: 1,
          maximum: 100,
        },
      });

      expect(Object.keys(responses).sort()).toEqual(
        ['200', '400', '502', '503'].sort(),
      );
      expect(responses['200'].content?.['application/json']?.schema).toEqual({
        $ref: '#/components/schemas/SearchResponseDto',
      });
      expect(document.components?.schemas?.SearchResponseDto).toBeDefined();
    } finally {
      await app.close();
    }
  });
});