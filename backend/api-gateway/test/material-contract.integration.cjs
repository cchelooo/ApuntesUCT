const assert = require('node:assert/strict');
const { test } = require('node:test');
const { Readable } = require('node:stream');
const CFB = require('cfb');
const { Test } = require('@nestjs/testing');
const { ConfigService } = require('@nestjs/config');
const { AppModule } = require('../dist/app.module');
const { configureRoutes } = require('../dist/configure-routes');
const {
  MaterialController,
} = require('../../material-service/dist/presentation/controllers/material.controller');
const {
  MaterialsController,
} = require('../../material-service/dist/presentation/materials/materials.controller');
const {
  MaterialsService,
} = require('../../material-service/dist/application/services/materials.service');
const {
  CreateMaterial,
} = require('../../material-service/dist/application/use-cases/create-material');
const {
  MaterialAuthorProvider,
} = require('../../material-service/dist/infrastructure/auth/material-author.provider');
const {
  PrismaService,
} = require('../../material-service/dist/infrastructure/prisma/prisma.service');
const {
  ObjectStorage,
} = require('../../material-service/dist/application/ports/object-storage.port');
const { setupApp } = require('../../material-service/dist/setup-app');
const {
  HttpExceptionFilter,
} = require('../../material-service/dist/infrastructure/filters/http-exception.filter');

// Uses the real HTTP controllers, validators and use cases with mocked persistence/storage.
// Reproduces the acceptance topology: clients only use the Gateway on 3000, which proxies
// to Material on its reserved 3003 for both multipart uploads and binary downloads.
// Run after building both api-gateway and material-service (Node handles file-type ESM).
test('Gateway → contrato HTTP real de Material', async (t) => {
  let material;
  let gateway;
  try {
    const binaryContent = Buffer.concat([
      Buffer.from('%PDF-1.7\n'),
      Buffer.from([0x00, 0x01, 0x7f, 0x80, 0xff, 0x0d, 0x0a, 0x42]),
    ]);
    let lastSavedBuffer = Buffer.alloc(0);
    let materialRow = { id: '11111111-1111-4111-8111-111111111111' };
    const versionRow = {
      storageKey: 'private/calculo-v1',
      mimeType: 'application/pdf',
      originalFilename: 'cálculo.pdf',
      fileSize: binaryContent.length,
    };
    const materialModule = await Test.createTestingModule({
      controllers: [MaterialController, MaterialsController],
      providers: [
        CreateMaterial,
        MaterialsService,
        {
          provide: MaterialAuthorProvider,
          useValue: {
            resolve: () => ({
              id: '11111111-1111-4111-8111-111111111111',
              universityId: null,
            }),
          },
        },
        {
          provide: ObjectStorage,
          useValue: {
            save: async (content) => { lastSavedBuffer = Buffer.isBuffer(content)?content:Buffer.from(content); return { storageKey: 'private/test' }; },
            get: async () => Readable.from([binaryContent]),
          },
        },
        {
          provide: PrismaService,
          useValue: {
            materialType: { findFirst: async () => ({ id: 'type-id' }) },
            material: {
              create: async ({ data }) => ({
                ...data,
                id: 'material-id',
                createdAt: new Date(),
              }),
              findFirst: async () => materialRow,
            },
            materialVersion: { findFirst: async () => versionRow },
          },
        },
      ],
    }).compile();
    material = materialModule.createNestApplication();
    setupApp(material);
    material.useGlobalFilters(new HttpExceptionFilter());
    // Material escucha en su puerto reservado; el Gateway usa ese valor por defecto.
    await material.listen(3003, '127.0.0.1');
    const gatewayModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(ConfigService)
      .useValue({ get: () => undefined })
      .compile();
    gateway = gatewayModule.createNestApplication();
    configureRoutes(gateway);
    // El cliente solo conoce el puerto 3000 del Gateway.
    await gateway.listen(3000, '127.0.0.1');
    const base = 'http://127.0.0.1:3000';
    const maxSize = 15 * 1024 * 1024;
    const post = async ({
      bytes,
      size = bytes?.length,
      mime = 'application/pdf',
      content = '%PDF-1.4\n',
      fields = {},
    } = {}) => {
      const body = new FormData();
      for (const [key, value] of Object.entries({
        title: 'Álgebra & cálculo',
        year: '2026',
        type: 'DOCUMENT',
        subjectId: 'subject-test',
        ...fields,
      })) {
        body.set(key, value);
      }
      if (size !== undefined) {
        const buffer = bytes ?? Buffer.alloc(size);
        if (!bytes) buffer.write(content);
        body.set('file', new Blob([buffer], { type: mime }), 'apuntes.pdf');
      }
      const response = await fetch(`${base}/api/v1/materials`, {
        method: 'POST',
        body,
      });
      return { status: response.status, body: await response.json() };
    };
    await t.test(
      'conserva multipart, metadatos Unicode y MIME detectado',
      async () => {
        const result = await post({
          size: 100,
          mime: 'application/octet-stream',
        });
        assert.equal(result.status, 201);
        assert.equal(result.body.isSimulatedResponse, false);
        assert.equal(result.body.data.title, 'Álgebra & cálculo');
        assert.equal(result.body.data.mimeType, 'application/pdf');
        assert.equal(result.body.data.fileSize, 100);
        assert.equal(result.body.data.status, 'PENDING_REVIEW');
      },
    );
    const officeFile = (streams, zip = false) => {
      const container = CFB.utils.cfb_new();
      for (const [name, value] of Object.entries(streams))
        CFB.utils.cfb_add(container, name, Buffer.from(value));
      return CFB.write(container, {
        type: 'buffer',
        fileType: zip ? 'zip' : 'cfb',
      });
    };
    for (const [label, mime, streams, zip] of [
      [
        'DOC',
        'application/msword',
        { WordDocument: 'word-data', '1Table': 'table-data' },
        false,
      ],
      [
        'PPT',
        'application/vnd.ms-powerpoint',
        { 'PowerPoint Document': 'slides', 'Current User': 'user' },
        false,
      ],
      [
        'DOCX',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        { 'word/document.xml': '<document/>' },
        true,
      ],
      [
        'PPTX',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        { 'ppt/presentation.xml': '<presentation/>' },
        true,
      ],
    ]) {
      await t.test(`detecta ${label} desde su contenedor`, async () => {
        if (zip)
          streams['[Content_Types].xml'] =
            `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/${Object.keys(streams)[0]}" ContentType="${mime}.main+xml"/></Types>`;
        const result = await post({
          bytes: officeFile(streams, zip),
          mime: 'application/octet-stream',
        });
        assert.equal(result.status, 201);
        assert.equal(result.body.data.mimeType, mime);
      });
    }
    await t.test('rechaza XLS disfrazado de DOC y CFB corrupto', async () => {
      const xls = await post({
        bytes: officeFile({ Workbook: 'spreadsheet' }),
        mime: 'application/msword',
      });
      assert.equal(xls.status, 415);
      const corrupt = await post({
        bytes: Buffer.from([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]),
        mime: 'application/msword',
      });
      assert.equal(corrupt.status, 415);
    });
    await t.test('acepta exactamente 15 MB', async () => {
      const result = await post({ size: maxSize });
      assert.equal(result.status, 201);
      assert.equal(result.body.data.fileSize, maxSize);
    });
    await t.test(
      'devuelve 413 por un byte de exceso conservando el formato de error',
      async () => {
        const result = await post({ size: maxSize + 1 });
        assert.equal(result.status, 413);
        assert.equal(result.body.statusCode, 413);
        assert.equal(result.body.path, '/api/v1/materials');
        assert.equal(typeof result.body.message, 'string');
      },
    );
    await t.test('rechaza texto aunque declare MIME PDF con 415', async () => {
      const result = await post({
        size: 100,
        content: 'contenido de texto falso',
      });
      assert.equal(result.status, 415);
      assert.equal(result.body.statusCode, 415);
    });
    await t.test(
      'permite LINK sin archivo y rechaza LINK con archivo',
      async () => {
        const fields = {
          type: 'LINK',
          externalLink: 'https://example.com/material',
        };
        const valid = await post({ fields });
        assert.equal(valid.status, 201);
        assert.equal(valid.body.data.fileUrl, null);
        assert.equal((await post({ fields, size: 100 })).status, 400);
      },
    );
    await t.test(
      'conserva 400 en metadatos inválidos y archivo ausente',
      async () => {
        assert.equal((await post()).status, 400);
        const result = await post({ fields: { year: 'abc' }, size: 100 });
        assert.equal(result.status, 400);
        assert.ok(Array.isArray(result.body.message));
      },
    );
    await t.test(
      'descarga el binario íntegro pasando por el Gateway',
      async () => {
        materialRow = { id: '11111111-1111-4111-8111-111111111111' };
        const response = await fetch(
          `${base}/api/v1/materials/11111111-1111-4111-8111-111111111111/download`,
        );
        assert.equal(response.status, 200);
        assert.equal(response.headers.get('content-type'), 'application/pdf');
        assert.equal(
          response.headers.get('content-disposition'),
          `attachment; filename="calculo.pdf"; filename*=UTF-8''c%C3%A1lculo.pdf`,
        );
        assert.equal(
          response.headers.get('content-length'),
          String(binaryContent.length),
        );
        const received = Buffer.from(await response.arrayBuffer());
        assert.ok(received.equals(binaryContent));
      },
    );
    await t.test('propaga el 404 del material a través del Gateway', async () => {
      materialRow = null;
      const response = await fetch(
        `${base}/api/v1/materials/22222222-2222-4222-8222-222222222222/download`,
      );
      assert.equal(response.status, 404);
      assert.equal((await response.json()).statusCode, 404);
    });
    await t.test(
      'rechaza un UUID inválido con 400 conservando el formato',
      async () => {
        const response = await fetch(`${base}/api/v1/materials/nope/download`);
        assert.equal(response.status, 400);
        assert.equal((await response.json()).statusCode, 400);
      },
    );
    await t.test(
      'responde 502 controlado después de cerrar Material',
      async () => {
        await material.close();
        const result = await post();
        assert.equal(result.status, 502);
        assert.equal(result.body.message, 'Material Service no disponible');
      },
    );
  } finally {
    await gateway?.close();
    await material?.close();
  }
});
