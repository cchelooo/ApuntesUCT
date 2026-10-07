import { configureRoutes } from '../src/configure-routes';
import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { createServer, Server } from 'node:http';
import { AddressInfo } from 'node:net';
import request from 'supertest';
import { AppModule } from '../src/app.module';

interface Upstream {
  server: Server;
  origin: string;
}

/** Microservicios incorporados al gateway en #222 y su ruta publica. */
const SERVICES = [
  { label: 'Material', path: 'materials', urlKey: 'MATERIAL_SERVICE_URL' },
  { label: 'Search', path: 'search', urlKey: 'SEARCH_SERVICE_URL' },
] as const;

async function startUpstream(label: string): Promise<Upstream> {
  const server = createServer((req, res) => {
    if (req.url === '/api/v1/materials/transport-test/download') {
      res.writeHead(200, {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': 'attachment; filename="apuntes.pdf"',
      });
      res.end(Buffer.from([0, 255, 128, 13, 10, 42]));
      return;
    }
    let body = '';
    req.on('data', (chunk: Buffer) => {
      body += chunk.toString();
    });
    req.on('end', () => {
      res.writeHead(200, {
        'Content-Type': 'application/json',
        'Set-Cookie': 'session=test; HttpOnly',
      });
      res.end(
        JSON.stringify({
          service: label,
          url: req.url,
          method: req.method,
          body,
          authorization: req.headers.authorization,
        }),
      );
    });
  });
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  return {
    server,
    origin: `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
  };
}

async function closeUpstream(server: Server): Promise<void> {
  if (!server.listening) return;
  await new Promise<void>((resolve, reject) =>
    server.close((err) => (err ? reject(err) : resolve())),
  );
}

/**
 * Puerto efímero que queda libre al cerrar el servidor: nada lo escucha, así que
 * cualquier conexión a él falla con ECONNREFUSED y el proxy responde 502.
 */
async function getClosedPort(): Promise<number> {
  const server = createServer();
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address() as AddressInfo;
  await new Promise<void>((resolve, reject) =>
    server.close((err) => (err ? reject(err) : resolve())),
  );
  return port;
}

describe('Gateway → Material y Search (HTTP)', () => {
  let gateway: INestApplication;
  const upstreams = new Map<string, Upstream>();

  beforeEach(async () => {
    const origins = new Map<string, string>();
    for (const service of SERVICES) {
      const upstream = await startUpstream(service.label);
      upstreams.set(service.label, upstream);
      origins.set(service.urlKey, upstream.origin);
    }
    // Auth no participa en este spec, pero el AppModule sí monta su proxy con el
    // origen por defecto (3001). Apuntarlo a un puerto cerrado evita que la prueba
    // dependa de que no haya nada escuchando en 3001: si Auth estuviera levantado,
    // la petición llegaría a un servicio real en vez de fallar con 502.
    origins.set(
      'AUTH_SERVICE_URL',
      `http://127.0.0.1:${await getClosedPort()}`,
    );

    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(ConfigService)
      .useValue({
        get: (key: string) => origins.get(key),
      })
      .compile();

    gateway = module.createNestApplication();
    configureRoutes(gateway);
    await gateway.init();
  });

  afterEach(async () => {
    await gateway?.close();
    for (const upstream of upstreams.values()) {
      await closeUpstream(upstream.server);
    }
    upstreams.clear();
  });

  it('conserva bytes y headers de una descarga del upstream simulado', async () => {
    const response = await request(gateway.getHttpServer())
      .get('/api/v1/materials/transport-test/download')
      .expect(200);
    expect(response.headers['content-type']).toBe('application/octet-stream');
    expect(response.headers['content-disposition']).toBe(
      'attachment; filename="apuntes.pdf"',
    );
    expect(response.body).toEqual(Buffer.from([0, 255, 128, 13, 10, 42]));
  });

  it.each(SERVICES)(
    'enruta $label a su propio origen sin alterar la ruta',
    async ({ path, label }) => {
      const res = await request(gateway.getHttpServer())
        .get(`/api/v1/${path}`)
        .expect(200);
      // Cada upstream responde con su propia etiqueta: confirma que cada ruta
      // llega al servicio correcto y no se cruzan los origenes.
      expect(res.body.service).toBe(label);
      expect(res.body.url).toBe(`/api/v1/${path}`);
    },
  );

  it.each(SERVICES)(
    'conserva el método, query, Authorization y cookies en $label',
    async ({ path, label }) => {
      const res = await request(gateway.getHttpServer())
        .get(`/api/v1/${path}/123?source=mobile&page=2`)
        .set('Authorization', 'Bearer test')
        .expect(200);
      expect(res.body.service).toBe(label);
      expect(res.body.method).toBe('GET');
      expect(res.body.url).toBe(`/api/v1/${path}/123?source=mobile&page=2`);
      expect(res.body.authorization).toBe('Bearer test');
      expect(res.headers['set-cookie']).toEqual(['session=test; HttpOnly']);
    },
  );

  it.each(SERVICES)(
    'conserva cuerpos JSON en $label',
    async ({ path, label }) => {
      const body = { titulo: 'Apuntes', semestre: 2 };
      const res = await request(gateway.getHttpServer())
        .post(`/api/v1/${path}`)
        .send(body)
        .expect(200);
      expect(res.body.service).toBe(label);
      expect(res.body.method).toBe('POST');
      expect(res.body.body).toBe(JSON.stringify(body));
    },
  );

  it.each(SERVICES)(
    'conserva PUT, PATCH y DELETE en $label',
    async ({ path, label }) => {
      const client = request(gateway.getHttpServer());
      for (const method of ['put', 'patch', 'delete'] as const) {
        const res = await client[method](`/api/v1/${path}/9`).expect(200);
        expect(res.body.service).toBe(label);
        expect(res.body.method).toBe(method.toUpperCase());
        expect(res.body.url).toBe(`/api/v1/${path}/9`);
      }
    },
  );

  it.each(SERVICES)(
    'devuelve 502 cuando $label no está disponible',
    async ({ path, label }) => {
      await closeUpstream(upstreams.get(label)!.server);
      await request(gateway.getHttpServer())
        .get(`/api/v1/${path}`)
        .expect(502)
        .expect({
          statusCode: 502,
          message: `${label} Service no disponible`,
        });
    },
  );

  it.each(SERVICES)('no captura rutas ajenas a $label', async ({ path }) => {
    await request(gateway.getHttpServer())
      .get(`/api/v1/${path}-other`)
      .expect(404);
  });

  it('mantiene el health local y el proxy de Auth sin interferencia', async () => {
    const health = await request(gateway.getHttpServer())
      .get('/api/v1/health')
      .expect(200);
    expect(health.body.service).toBe('API Gateway');
    await request(gateway.getHttpServer()).get('/health').expect(200);
    // Auth apunta a un puerto cerrado (definido en beforeEach): debe responder su
    // propio 502, no uno de Material/Search.
    await request(gateway.getHttpServer())
      .get('/api/v1/auth/login')
      .expect(502)
      .expect({ statusCode: 502, message: 'Auth Service no disponible' });
  });
});

describe('Gateway → Material y Search (orígenes por defecto)', () => {
  // El origen por defecto de cada proxy (puertos reservados 3003 y 3005) y el
  // mensaje del 502 se comprueban en src/modules/proxy/proxy.module.spec.ts,
  // donde se inspeccionan las opciones del proxy sin abrir puertos. Aquí solo se
  // verifica el 502 sobre HTTP real, contra un puerto cerrado.
  it.each([
    ['Material', 'materials', 'MATERIAL_SERVICE_URL', 'Material Service'],
    ['Search', 'search', 'SEARCH_SERVICE_URL', 'Search Service'],
  ])(
    'responde 502 propio de %s cuando su origen no acepta conexiones',
    async (_label, path, urlKey, serviceName) => {
      const closedPort = await getClosedPort();
      const module = await Test.createTestingModule({ imports: [AppModule] })
        .overrideProvider(ConfigService)
        .useValue({
          get: (key: string) =>
            key === urlKey ? `http://127.0.0.1:${closedPort}` : undefined,
        })
        .compile();
      const isolated = module.createNestApplication();
      configureRoutes(isolated);
      await isolated.init();

      try {
        await request(isolated.getHttpServer())
          .get(`/api/v1/${path}`)
          .expect(502)
          .expect({ statusCode: 502, message: `${serviceName} no disponible` });
      } finally {
        await isolated.close();
      }
    },
  );
});
