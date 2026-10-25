import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  DocumentBuilder,
  SwaggerModule,
  type OpenAPIObject,
} from '@nestjs/swagger';

interface DocsService {
  name: string;
  description: string;
  url: string;
}

function renderDocsIndex(services: DocsService[]): string {
  const rows = services
    .map(
      (service) => `
    <tr>
      <td>${service.name}</td>
      <td>${service.description}</td>
      <td><a href="${service.url}">${service.url}</a></td>
    </tr>`,
    )
    .join('');

  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>API Gateway — Documentación</title>
    <style>
      body { font-family: system-ui, sans-serif; margin: 0; padding: 2rem; background: #f5f6f8; color: #1f2937; }
      main { max-width: 48rem; margin: 0 auto; background: #fff; border: 1px solid #e5e7eb; border-radius: 0.5rem; padding: 2rem; }
      h1 { margin-top: 0; }
      a { color: #2563eb; text-decoration: none; }
      table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
      th, td { text-align: left; padding: 0.6rem 0.4rem; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
      th { color: #6b7280; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.05em; }
    </style>
  </head>
  <body>
    <main>
      <h1>API Gateway — Documentación</h1>
      <p>Documentación OpenAPI (Swagger) de los servicios del backend de ApuntesUCT.</p>
      <table>
        <thead>
          <tr><th>Servicio</th><th>Descripción</th><th>Documentación</th></tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
      <p>Quality Service todavía no está enrutado por el gateway. Material y Search sí lo
      están: <code>/api/v1/materials</code> devuelve el listado paginado de materiales y
      <code>/api/v1/search</code> compone esos materiales con el contexto académico de
      Catalog. Las rutas públicas son las del Gateway (puerto 3000); Web y Mobile no
      necesitan conocer el puerto <code>3005</code> de Search. El <code>502</code>
      corresponde al servicio caído (o a una dependencia con respuesta inválida) y el
      <code>503</code> a una dependencia de Search no disponible.</p>
    </main>
  </body>
</html>`;
}

const SEARCH_PATH = '/api/v1/search';

const SEARCH_SCHEMAS: NonNullable<OpenAPIObject['components']>['schemas'] = {
  ErrorResponse: {
    type: 'object',
    required: ['statusCode', 'message'],
    properties: {
      statusCode: { type: 'integer' },
      message: {
        oneOf: [{ type: 'string' }, { type: 'array', items: { type: 'string' } }],
      },
      error: { type: 'string' },
    },
  },
  SearchProfessor: {
    type: 'object',
    required: ['id', 'name'],
    properties: {
      id: { type: 'string' },
      name: { type: 'string' },
    },
  },
  SearchSubjectContext: {
    type: 'object',
    required: [
      'subjectId',
      'subjectName',
      'subjectCode',
      'semester',
      'careerId',
      'careerName',
      'universityId',
      'universityName',
      'professors',
    ],
    properties: {
      subjectId: { type: 'string' },
      subjectName: { type: 'string' },
      subjectCode: { type: 'string', nullable: true },
      semester: { type: 'integer', nullable: true },
      careerId: { type: 'string', nullable: true },
      careerName: { type: 'string', nullable: true },
      universityId: { type: 'string', nullable: true },
      universityName: { type: 'string', nullable: true },
      professors: {
        type: 'array',
        items: { $ref: '#/components/schemas/SearchProfessor' },
      },
    },
  },
  SearchResult: {
    type: 'object',
    required: [
      'id',
      'title',
      'description',
      'materialType',
      'academicYear',
      'verified',
      'subjectId',
      'careerId',
      'universityId',
      'professorId',
      'subjectName',
      'careerName',
      'universityName',
      'createdAt',
      'updatedAt',
    ],
    properties: {
      id: { type: 'string' },
      title: { type: 'string' },
      description: { type: 'string', nullable: true },
      materialType: { type: 'string', nullable: true },
      academicYear: { type: 'integer', nullable: true },
      verified: { type: 'boolean' },
      subjectId: { type: 'string', nullable: true },
      careerId: { type: 'string', nullable: true },
      universityId: { type: 'string', nullable: true },
      professorId: { type: 'string', nullable: true },
      subjectName: { type: 'string', nullable: true },
      careerName: { type: 'string', nullable: true },
      universityName: { type: 'string', nullable: true },
      createdAt: { type: 'string', format: 'date-time', nullable: true },
      updatedAt: { type: 'string', format: 'date-time', nullable: true },
    },
  },
  SearchResponse: {
    type: 'object',
    required: ['query', 'page', 'pageSize', 'total', 'results', 'context'],
    properties: {
      query: { type: 'string', nullable: true },
      page: { type: 'integer' },
      pageSize: { type: 'integer' },
      total: { type: 'integer' },
      results: {
        type: 'array',
        items: { $ref: '#/components/schemas/SearchResult' },
      },
      context: {
        type: 'array',
        items: { $ref: '#/components/schemas/SearchSubjectContext' },
      },
    },
  },
};

/** Documenta la ruta pública de Search sin obligar a consultar el puerto 3005. */
function addSearchDocumentation(document: OpenAPIObject): void {
  document.paths[SEARCH_PATH] = {
    get: {
      tags: ['Search'],
      summary: 'Buscar materiales y recursos',
      description:
        'Compone el listado paginado de Material con el contexto académico resuelto por Catalog. ' +
        'La respuesta conserva el contrato público de Search.',
      parameters: [
        {
          name: 'q',
          in: 'query',
          required: false,
          description:
            'Término de búsqueda textual. Se devuelve en el campo `query` de la respuesta.',
          schema: { type: 'string', maxLength: 200 },
          example: 'Estructuras de Datos',
        },
        {
          name: 'page',
          in: 'query',
          required: false,
          description: 'Página solicitada, comenzando en 1.',
          schema: {
            type: 'integer',
            default: 1,
            minimum: 1,
            maximum: 2147483647,
          },
          example: 1,
        },
        {
          name: 'pageSize',
          in: 'query',
          required: false,
          description: 'Cantidad de resultados por página (máximo 100).',
          schema: {
            type: 'integer',
            default: 20,
            minimum: 1,
            maximum: 100,
          },
          example: 20,
        },
      ],
      responses: {
        '200': {
          description:
            'Materiales candidatos con su contexto académico.',
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/SearchResponse' },
            },
          },
        },
        '400': {
          description:
            'Parámetros de consulta inválidos o paginación rechazada por Material Service.',
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/ErrorResponse' },
            },
          },
        },
        '502': {
          description:
            'Search Service no está disponible o una dependencia devolvió una respuesta inválida.',
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/ErrorResponse' },
            },
          },
        },
        '503': {
          description:
            'Una dependencia de Search (Catalog o Material) no está disponible.',
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/ErrorResponse' },
            },
          },
        },
      },
    },
  };

  document.components = {
    ...document.components,
    schemas: {
      ...document.components?.schemas,
      ...SEARCH_SCHEMAS,
    },
  };
}

export function setupApiDocs(
  app: INestApplication,
  configService: ConfigService,
): void {
  const swaggerConfig = new DocumentBuilder()
    .setTitle('API Gateway')
    .setDescription(
      'Punto único de entrada a los microservicios de ApuntesUCT.',
    )
    .setVersion('0.0.1')
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  addSearchDocumentation(document);
  SwaggerModule.setup('api/docs/gateway', app, document);

  const services: DocsService[] = [
    {
      name: 'API Gateway',
      description: 'Punto único de entrada a los microservicios de ApuntesUCT.',
      url: '/api/docs/gateway',
    },
    {
      name: 'Auth Service',
      description: 'Autenticación y gestión de usuarios.',
      url: configService.get<string>(
        'AUTH_DOCS_URL',
        'http://localhost:3001/api/docs',
      ),
    },
    {
      name: 'Catalog Service',
      description: 'Catálogo de asignaturas y apuntes.',
      url: configService.get<string>(
        'CATALOG_DOCS_URL',
        'http://localhost:3002/api/docs',
      ),
    },
    {
      name: 'Material Service',
      description: 'Materiales, metadatos, archivos, versiones y descargas.',
      url: configService.get<string>(
        'MATERIAL_DOCS_URL',
        'http://localhost:3003/api/docs',
      ),
    },
    {
      name: 'Search Service',
      description: 'Búsqueda, filtros, ordenamiento y posicionamiento.',
      url: configService.get<string>(
        'SEARCH_DOCS_URL',
        'http://localhost:3005/api/docs',
      ),
    },
  ];

  app
    .getHttpAdapter()
    .get('/api/docs', (_req, res) => res.send(renderDocsIndex(services)));
}
