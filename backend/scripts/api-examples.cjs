// Illustrative fixtures for public documentation; never production captures.
const timestamp = '2026-11-08T12:00:00.000Z';
const materialId = '00000000-0000-4000-8000-000000000001';
const version = {
  id: '00000000-0000-4000-8000-000000000002',
  versionNumber: 2,
  originalFilename: 'guia-v2.pdf',
  mimeType: 'application/pdf',
  fileSize: '2048',
  createdAt: timestamp,
};
const detail = {
  id: materialId,
  title: 'Guía de álgebra',
  description: null,
  uploaderId: '00000000-0000-4000-8000-000000000092',
  academicOfferingId: null,
  universityId: null,
  careerId: null,
  subjectId: '33333333-3333-4333-8333-333333333333',
  professorId: null,
  materialTypeId: '00000000-0000-4000-8000-000000000003',
  materialType: 'DOCUMENT',
  academicYear: 2026,
  status: 'PUBLISHED',
  verified: false,
  externalLink: null,
  createdAt: timestamp,
  updatedAt: timestamp,
  currentVersion: version,
  versions: [version],
};
const errors = {
  400: 'El desplazamiento de página excede el máximo permitido.',
  401: 'Se requiere un contexto de autor válido.',
  403: 'Solo el autor puede crear una nueva versión del material.',
  404: 'Material no encontrado.',
  413: 'El archivo excede el tamaño máximo permitido de 15 MB (15728640 bytes).',
  415: 'Tipo de archivo no admitido. Formatos válidos: PDF, Word (.doc, .docx) y PowerPoint (.ppt, .pptx).',
  500: 'Internal server error',
  502: 'No se pudo almacenar el archivo. Intenta nuevamente.',
  503: 'Almacenamiento de archivos no disponible.',
};
const { STATUS_CODES } = require('node:http');
function addExamples(service, document) {
  for (const [route, pathItem] of Object.entries(document.paths)) {
    for (const [method, operation] of Object.entries(pathItem)) {
      if (!operation.responses) continue;
      for (const [code, response] of Object.entries(operation.responses)) {
        let example;
        if (service === 'Material Service') {
          if (code === '200' && route === '/api/v1/materials')
            example = { items: [], page: 1, pageSize: 20, total: 0 };
          if (code === '200' && route === '/api/v1/materials/{id}') example = detail;
          if (code === '201' && route.endsWith('/versions'))
            example = { ...version, materialId, createdBy: detail.uploaderId };
          if (+code >= 400) {
            example = {
              statusCode: +code,
              error: STATUS_CODES[code],
              message:
                +code === 400 && route !== '/api/v1/materials'
                  ? 'Validation failed (uuid is expected)'
                  : errors[code],
              timestamp,
              path: route.replace('{id}', materialId),
            };
            if (code === '400' && method === 'post' && route === '/api/v1/materials')
              example.message = ['title should not be empty'];
            // @ApiProduces applies to all responses in Nest, but exceptions are JSON.
            const schema = Object.values(response.content ?? {})[0]?.schema;
            response.content = { 'application/json': { schema } };
          }
        }
        if (service === 'Search Service' && code === '200')
          example = {
            query: 'Estructuras de Datos',
            page: 1,
            pageSize: 20,
            total: 0,
            results: [],
            context: [],
          };
        if (example) response.content['application/json'].example = example;
      }
    }
  }
}
module.exports = { addExamples };
