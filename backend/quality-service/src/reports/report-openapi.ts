import type { SchemaObject } from '@nestjs/swagger';
export const ReportDto: SchemaObject = {
  type: 'object',
  additionalProperties: false,
  required: [
    'id',
    'materialId',
    'userId',
    'reason',
    'details',
    'status',
    'resolutionNote',
    'createdAt',
    'updatedAt',
  ],
  properties: {
    id: {
      type: 'string',
      format: 'uuid',
    },
    materialId: {
      type: 'string',
      format: 'uuid',
    },
    userId: {
      type: 'string',
      format: 'uuid',
    },
    reason: {
      type: 'string',
      enum: [
        'INAPPROPRIATE_CONTENT',
        'COPYRIGHT',
        'INCORRECT_INFORMATION',
        'BROKEN_RESOURCE',
        'OTHER',
      ],
    },
    details: {
      type: 'string',
      nullable: true,
    },
    status: {
      type: 'string',
      enum: ['OPEN', 'IN_REVIEW', 'RESOLVED', 'DISMISSED'],
    },
    resolutionNote: {
      type: 'string',
      nullable: true,
    },
    createdAt: {
      type: 'string',
      format: 'date-time',
    },
    updatedAt: {
      type: 'string',
      format: 'date-time',
    },
  },
};
export const ReportCreateDto: SchemaObject = {
  type: 'object',
  additionalProperties: false,
  required: ['reason'],
  properties: {
    reason: {
      type: 'string',
      enum: [
        'INAPPROPRIATE_CONTENT',
        'COPYRIGHT',
        'INCORRECT_INFORMATION',
        'BROKEN_RESOURCE',
        'OTHER',
      ],
    },
    details: {
      type: 'string',
      nullable: true,
      maxLength: 2000,
    },
  },
  description:
    'OTHER exige details no vacío después de trim. Los demás motivos admiten details null u omitido.',
  example: {
    reason: 'BROKEN_RESOURCE',
    details: 'El enlace externo ya no permite acceder al documento.',
  },
};
export const ReportUpdateDto: SchemaObject = {
  type: 'object',
  additionalProperties: false,
  required: ['status', 'expectedUpdatedAt'],
  properties: {
    status: {
      type: 'string',
      enum: ['IN_REVIEW', 'RESOLVED', 'DISMISSED'],
    },
    expectedUpdatedAt: {
      type: 'string',
      format: 'date-time',
    },
    resolutionNote: {
      type: 'string',
      minLength: 1,
      maxLength: 2000,
      pattern: '\\S',
    },
  },
  description:
    'RESOLVED y DISMISSED requieren resolutionNote. Conflicto de expectedUpdatedAt: 409. Resolver un reporte no cambia publicación.',
};
export const ReportPageDto: SchemaObject = {
  type: 'object',
  additionalProperties: false,
  required: ['items', 'page', 'pageSize', 'total'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: [
          'id',
          'materialId',
          'userId',
          'reason',
          'details',
          'status',
          'resolutionNote',
          'createdAt',
          'updatedAt',
        ],
        properties: {
          id: {
            type: 'string',
            format: 'uuid',
          },
          materialId: {
            type: 'string',
            format: 'uuid',
          },
          userId: {
            type: 'string',
            format: 'uuid',
          },
          reason: {
            type: 'string',
            enum: [
              'INAPPROPRIATE_CONTENT',
              'COPYRIGHT',
              'INCORRECT_INFORMATION',
              'BROKEN_RESOURCE',
              'OTHER',
            ],
          },
          details: {
            type: 'string',
            nullable: true,
          },
          status: {
            type: 'string',
            enum: ['OPEN', 'IN_REVIEW', 'RESOLVED', 'DISMISSED'],
          },
          resolutionNote: {
            type: 'string',
            nullable: true,
          },
          createdAt: {
            type: 'string',
            format: 'date-time',
          },
          updatedAt: {
            type: 'string',
            format: 'date-time',
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
