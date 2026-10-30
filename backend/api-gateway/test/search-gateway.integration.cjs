const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createServer } = require('node:http');
const { Test } = require('@nestjs/testing');
const { ValidationPipe } = require('@nestjs/common');
const { ConfigService } = require('@nestjs/config');
const { AppModule: GatewayModule } = require('../dist/app.module');
const { configureRoutes } = require('../dist/configure-routes');
const { AppModule: SearchModule } = require('../../search-service/dist/app.module');

test('Gateway → contrato HTTP real de Search', async (t) => {
  let gateway;
  let search;
  let catalog;
  let material;
  let catalogMode = 'ok';
  let materialMode = 'ok';
  const catalogCalls = [];
  const materialCalls = [];

  const catalogSubject = () => ({
    id: 'subject-1',
    name: 'Estructuras de Datos',
    code: 'INF-201',
    semester: 3,
    careerId: 'career-1',
    career: {
      id: 'career-1',
      name: 'Ingeniería Civil Informática',
      universityId: 'university-1',
      university: {
        id: 'university-1',
        name: 'Universidad Católica de Temuco',
      },
    },
    professors: [{ id: 'professor-1', name: 'Ada Lovelace' }],
  });

  const materialCandidate = () => ({
    id: 'material-1',
    title: 'Apunte de listas enlazadas',
    description: null,
    materialType: 'APUNTE',
    academicYear: 2026,
    verified: true,
    subjectId: 'subject-1',
    careerId: 'career-1',
    universityId: 'university-1',
    professorId: 'professor-1',
    createdAt: '2026-10-01T00:00:00.000Z',
    updatedAt: '2026-10-02T00:00:00.000Z',
  });

  const respondJson = (res, status, body) => {
    res.writeHead(status, { 'content-type': 'application/json' });
    res.end(JSON.stringify(body));
  };

  const startMock = async (handle) => {
    const server = createServer((req, res) => {
      const url = new URL(req.url, 'http://127.0.0.1');
      handle(req, res, url);
    });
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.listen(0, '127.0.0.1', resolve);
    });
    return {
      server,
      get origin() {
        return http://127.0.0.1:;
      },
    };
  };

  const closeServer = async (instance) => {
    if (!instance?.server?.listening) return;
    instance.server.closeAllConnections?.();
    await new Promise((resolve, reject) =>
      instance.server.close((error) => (error ? reject(error) : resolve())),
    );
  };

  try {
    catalog = await startMock((req, res, url) => {
      catalogCalls.push(${url.pathname});
      if (catalogMode === 'down') {
        req.socket.destroy();
        return;
      }
      if (catalogMode === 'invalid') {
        respondJson(res, 200, [
          { ...catalogSubject(), professors: {} },
        ]);
        return;
      }
      respondJson(res, 200, [catalogSubject()]);
    });

    material = await startMock((req, res, url) => {
      materialCalls.push(${url.pathname});
      if (materialMode === 'down') {
        req.socket.destroy();
        return;
      }
      if (materialMode === 'rejected') {
        respondJson(res, 400, {
          message: 'El desplazamiento de página excede el máximo permitido.',
        });
        return;
      }
      if (materialMode === 'error') {
        respondJson(res, 500, { message: 'fallo interno simulado' });
        return;
      }

      const page = Number(url.searchParams.get('page'));
      const pageSize = Number(url.searchParams.get('pageSize'));
      if (materialMode === 'invalid') {
        respondJson(res, 200, {
          items: [{ ...materialCandidate(), verified: 'si' }],
          page,
          pageSize,
          total: 7,
        });
        return;
      }
      respondJson(res, 200, {
        items: [materialCandidate()],
        page,
        pageSize,
        total: 7,
      });
    });

    process.env.CATALOG_SERVICE_URL = catalog.origin;
    process.env.MATERIAL_SERVICE_URL = material.origin;

    const searchModule = await Test.createTestingModule({
      imports: [SearchModule],
    }).compile();
    search = searchModule.createNestApplication();
    search.useGlobalPipes(
      new ValidationPipe({ transform: true, whitelist: true }),
    );
    await search.listen(0, '127.0.0.1');
    const searchOrigin = http://127.0.0.1:;

    const origins = new Map([
      ['SEARCH_SERVICE_URL', searchOrigin],
      ['AUTH_SERVICE_URL', 'http://127.0.0.1:1'],
      ['CATALOG_SERVICE_URL', 'http://127.0.0.1:1'],
      ['MATERIAL_SERVICE_URL', 'http://127.0.0.1:1'],
    ]);
    const gatewayModule = await Test.createTestingModule({
      imports: [GatewayModule],
    })
      .overrideProvider(ConfigService)
      .useValue({ get: (key) => origins.get(key) })
      .compile();
    gateway = gatewayModule.createNestApplication();
    configureRoutes(gateway);
    await gateway.listen(0, '127.0.0.1');
    const gatewayOrigin = http://127.0.0.1:;

    const get = async (path) => {
      const response = await fetch(${gatewayOrigin});
      const body = await response.json();
      return { status: response.status, body };
    };

    await t.test('expone la búsqueda compuesta sin conocer el puerto 3005', async () => {
      const result = await get('/api/v1/search?q=listas');
      assert.equal(result.status, 200);
      assert.equal(result.body.query, 'listas');
      assert.equal(result.body.page, 1);
      assert.equal(result.body.pageSize, 20);
      assert.equal(result.body.total, 1);
      assert.equal(result.body.results.length, 1);
      assert.equal(result.body.results[0].subjectName, 'Estructuras de Datos');
      assert.equal(result.body.results[0].universityName, 'Universidad Católica de Temuco');
      assert.equal(result.body.context.length, 1);
      assert.equal(result.body.context[0].subjectCode, 'INF-201');
      assert.ok(materialCalls.some((call) => call.startsWith('/api/v1/materials?page=1&pageSize=100')));
      assert.ok(catalogCalls.at(-1).startsWith('/api/v1/catalog/filter'));
    });

    await t.test('reenvía la paginación a Material y conserva q en la respuesta', async () => {
      const result = await get('/api/v1/search?q=grafos&page=2&pageSize=5');
      assert.equal(result.status, 200);
      assert.equal(result.body.query, 'grafos');
      assert.equal(result.body.page, 2);
      assert.equal(result.body.pageSize, 5);
      assert.ok(materialCalls.some((call) => call.startsWith('/api/v1/materials?page=1&pageSize=100')));
    });

    await t.test('rechaza parámetros inválidos con 400 antes de llamar a las dependencias', async () => {
      for (const path of [
        '/api/v1/search?page=0',
        '/api/v1/search?pageSize=101',
        /api/v1/search?q=,
      ]) {
        const result = await get(path);
        assert.equal(result.status, 400);
        assert.equal(result.body.statusCode, 400);
      }
    });

    await t.test('propaga como 400 la paginación rechazada por Material', async () => {
      materialMode = 'rejected';
      const result = await get('/api/v1/search?page=2147483647&pageSize=100');
      assert.equal(result.status, 400);
      assert.equal(result.body.statusCode, 400);
      assert.match(result.body.message, /no es válida para Material Service/);
    });

    await t.test('responde 502 cuando Material devuelve un payload inválido', async () => {
      materialMode = 'invalid';
      const result = await get('/api/v1/search');
      assert.equal(result.status, 502);
      assert.equal(result.body.statusCode, 502);
      assert.match(result.body.message, /campos inválidos/);
    });

    await t.test('responde 502 cuando Catalog devuelve un payload inválido', async () => {
      catalogMode = 'invalid';
      materialMode = 'ok';
      const result = await get('/api/v1/search');
      assert.equal(result.status, 502);
      assert.equal(result.body.statusCode, 502);
      assert.match(result.body.message, /profesores con campos inválidos/);
    });

    await t.test('responde 503 cuando una dependencia no está disponible', async () => {
      catalogMode = 'ok';
      materialMode = 'down';
      const result = await get('/api/v1/search');
      assert.equal(result.status, 503);
      assert.equal(result.body.statusCode, 503);
      assert.match(result.body.message, /Material Service no está disponible/);
    });

    await t.test('se recupera cuando la dependencia vuelve a responder', async () => {
      materialMode = 'ok';
      const result = await get('/api/v1/search');
      assert.equal(result.status, 200);
      assert.equal(result.body.total, 1);
    });

    await t.test('el Gateway responde 502 propio cuando Search está caído', async () => {
      search.getHttpServer().closeAllConnections?.();
      await search.close();
      search = undefined;
      const result = await get('/api/v1/search');
      assert.equal(result.status, 502);
      assert.deepEqual(result.body, {
        statusCode: 502,
        message: 'Search Service no disponible',
      });
    });
  } finally {
    delete process.env.CATALOG_SERVICE_URL;
    delete process.env.MATERIAL_SERVICE_URL;
    await gateway?.close();
    if (search) {
      search.getHttpServer().closeAllConnections?.();
      await search.close();
    }
    await closeServer(catalog);
    await closeServer(material);
  }
});