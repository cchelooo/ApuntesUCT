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

  it.each(SERVICES)('conserva cuerpos JSON en $label', async ({ path, label }) => {
    const body = { titulo: 'Apuntes', semestre: 2 };
    const res = await request(gateway.getHttpServer())
      .post(`/api/v1/${path}`)
      .send(body)
      .expect(200);
    expect(res.body.service).toBe(label);
    expect(res.body.method).toBe('POST');
    expect(res.body.body).toBe(JSON.stringify(body));
  });

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

  it.each(SERVICES)(
    'no captura rutas ajenas a $label',
    async ({ path }) => {
      await request(gateway.getHttpServer())
        .get(`/api/v1/${path}-other`)
        .expect(404);
    },
  );

  it('mantiene el health local y el proxy de Auth sin interferencia', async () => {
    const health = await request(gateway.getHttpServer())
      .get('/api/v1/health')
      .expect(200);
    expect(health.body.service).toBe('API Gateway');
    await request(gateway.getHttpServer()).get('/health').expect(200);
    // Auth no tiene origen configurado en este test: debe responder 502 suyo, no de Material/Search.
    await request(gateway.getHttpServer())
      .get('/api/v1/auth/login')
      .expect(502)
      .expect({ statusCode: 502, message: 'Auth Service no disponible' });
  });
});

describe('Gateway → Material y Search (orígenes por defecto)', () => {
  let gateway: INestApplication;

  beforeEach(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(ConfigService)
      .useValue({ get: () => undefined })
      .compile();
    gateway = module.createNestApplication();
    configureRoutes(gateway);
    await gateway.init();
  });

  afterEach(async () => {
    await gateway?.close();
  });

  // Sin MATERIAL_SERVICE_URL ni SEARCH_SERVICE_URL el gateway usa los puertos
  // reservados 3003 y 3005. Nada los escucha en el entorno de pruebas, así que
  // se verifica el mensaje 502 propio de cada servicio.
  it.each([
    ['Material', 'materials', 'Material Service'],
    ['Search', 'search', 'Search Service'],
  ])(
    'usa el puerto reservado de %s y reporta su propio 502',
    async (_label, path, serviceName) => {
      await request(gateway.getHttpServer())
        .get(`/api/v1/${path}`)
        .expect(502)
        .expect({ statusCode: 502, message: `${serviceName} no disponible` });
    },
  );
});