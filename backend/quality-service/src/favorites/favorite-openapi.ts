import type { SchemaObject } from '@nestjs/swagger';
export const FavoriteDto: SchemaObject = {
  type: 'object',
  additionalProperties: false,
  required: ['id', 'materialId', 'createdAt', 'available'],
  properties: {
    id: {
      type: 'string',
      format: 'uuid',
    },
    materialId: {
      type: 'string',
      format: 'uuid',
    },
    createdAt: {
      type: 'string',
      format: 'date-time',
    },
    available: {
      type: 'boolean',
      description:
        'Visibilidad pública comprobada al leer. false conserva únicamente esta referencia propia, sin metadatos del material ni URL.',
    },
  },
};
export const FavoritePageDto: SchemaObject = {
  type: 'object',
  additionalProperties: false,
  required: ['items', 'page', 'pageSize', 'total'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'materialId', 'createdAt', 'available'],
        properties: {
          id: {
            type: 'string',
            format: 'uuid',
          },
          materialId: {
            type: 'string',
            format: 'uuid',
          },
          createdAt: {
            type: 'string',
            format: 'date-time',
          },
          available: {
            type: 'boolean',
            description:
              'Visibilidad pública comprobada al leer. false conserva únicamente esta referencia propia, sin metadatos del material ni URL.',
          },
        },
      },
    },
    page: {
      type: 'integer',
      minimum: 1,
    },
    pageSize: {
      type: 'integer',
      minimum: 1,
      maximum: 100,
    },
    total: {
      type: 'integer',
      minimum: 0,
    },
  },
};
export const ErrorDto: SchemaObject = {
  type: 'object',
  additionalProperties: false,
  required: ['statusCode', 'code', 'message', 'requestId'],
  properties: {
    statusCode: {
      type: 'integer',
      minimum: 400,
      maximum: 599,
    },
    code: {
      type: 'string',
    },
    message: {
      type: 'string',
    },
    field: {
      type: 'string',
    },
    requestId: {
      type: 'string',
      format: 'uuid',
    },
  },
  example: {
    statusCode: 409,
    code: 'STALE_REVISION',
    message: 'El material cambió. Vuelve a consultar antes de decidir.',
    requestId: '11111111-1111-4111-8111-111111111111',
  },
};
