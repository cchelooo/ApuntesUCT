const assert = require('node:assert/strict');
const { test } = require('node:test');
const CFB = require('cfb');
const { Test } = require('@nestjs/testing');
const { ConfigService } = require('@nestjs/config');
const { AppModule } = require('../dist/app.module');
const { configureRoutes } = require('../dist/configure-routes');
const {
  MaterialController,
} = require('../../material-service/dist/presentation/controllers/material.controller');
const { setupApp } = require('../../material-service/dist/setup-app');
const {
  HttpExceptionFilter,
} = require('../../material-service/dist/infrastructure/filters/http-exception.filter');

// Uses the real HTTP controller and validators. POST is still a stub; no database or storage.
// Run after building both api-gateway and material-service (Node handles file-type ESM).
test('Gateway → contrato HTTP real de Material', async (t) => {
  let material;
  let gateway;
  try {
    const materialModule = await Test.createTestingModule({
      controllers: [MaterialController],
    }).compile();
    material = materialModule.createNestApplication();
    setupApp(material);
    material.useGlobalFilters(new HttpExceptionFilter());
    await material.listen(0, '127.0.0.1');
    const target = await material.getUrl();
    const gatewayModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider(ConfigService)
      .useValue({
        get: (key) => (key === 'MATERIAL_SERVICE_URL' ? target : undefined),
      })
      .compile();
    gateway = gatewayModule.createNestApplication();
    configureRoutes(gateway);
    await gateway.listen(0, '127.0.0.1');
    const base = await gateway.getUrl();
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
        assert.equal(result.body.isSimulatedResponse, true);
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
