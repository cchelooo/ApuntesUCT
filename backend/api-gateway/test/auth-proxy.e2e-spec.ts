import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { createServer, Server } from 'node:http';
import { AddressInfo } from 'node:net';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { HealthModule } from '../../auth-service/src/presentation/health/health.module';
import { AuthModule } from '../../auth-service/src/presentation/auth/auth.module';

describe('Gateway → Auth (HTTP)', () => {
  let gateway: INestApplication;
  let upstream: Server;
  let target: string;

  beforeEach(async () => {
    upstream = createServer((req, res) => {
      let body = '';
      req.on('data', (chunk: Buffer) => {
        body += chunk.toString();
      });
      req.on('end', () => {
        res.writeHead(req.url?.includes('/login') ? 401 : 200, {
          'Content-Type': 'application/json',
          'Set-Cookie': 'session=test; HttpOnly',
        });
        res.end(
          JSON.stringify({
            url: req.url,
            method: req.method,
            body,
            authorization: req.headers.authorization,
          }),
        );
      });
    });
    await new Promise<void>((resolve, reject) => {
      upstream.once('error', reject);
      upstream.listen(0, '127.0.0.1', resolve);
    });
    target = `http://127.0.0.1:${(upstream.address() as AddressInfo).port}`;
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(ConfigService)
      .useValue({
        get: (key: string) => (key === 'AUTH_SERVICE_URL' ? target : undefined),
      })
      .compile();
    gateway = module.createNestApplication();
    gateway.setGlobalPrefix('api/v1');
    await gateway.init();
  });

  afterEach(async () => {
    await gateway?.close();
    if (upstream.listening) {
      await new Promise<void>((resolve, reject) =>
        upstream.close((err) => (err ? reject(err) : resolve())),
      );
    }
  });

  it('conserva POST, JSON, query, Authorization, cookies y errores de Auth', async () => {
    const body = { email: 'estudiante@alu.uct.cl', password: 'test' };
    const res = await request(gateway.getHttpServer())
      .post('/api/v1/auth/login?source=mobile')
      .set('Authorization', 'Bearer test')
      .send(body)
      .expect(401);
    expect(res.body).toEqual({
      url: '/api/v1/auth/login?source=mobile',
      method: 'POST',
      body: JSON.stringify(body),
      authorization: 'Bearer test',
    });
    expect(res.headers['set-cookie']).toEqual(['session=test; HttpOnly']);
  });

  it.each(['get', 'put', 'patch', 'delete'] as const)(
    'conserva el método %s',
    async (method) => {
      const client = request(gateway.getHttpServer());
      const res = await client[method]('/api/v1/auth/users/123').expect(200);
      expect(res.body.method).toBe(method.toUpperCase());
      expect(res.body.url).toBe('/api/v1/auth/users/123');
    },
  );

  it('redirige health de Auth y conserva su query', async () => {
    const res = await request(gateway.getHttpServer())
      .get('/api/v1/auth/health?check=1')
      .expect(200);
    expect(res.body.url).toBe('/api/v1/health?check=1');
  });

  it('mantiene health local y no captura rutas ajenas', async () => {
    const res = await request(gateway.getHttpServer())
      .get('/api/v1/health')
      .expect(200);
    expect(res.body.service).toBe('API Gateway');
    await request(gateway.getHttpServer())
      .get('/api/v1/auth-other')
      .expect(404);
  });

  it('devuelve 502 cuando Auth no está disponible', async () => {
    await new Promise<void>((resolve) => upstream.close(() => resolve()));
    await request(gateway.getHttpServer())
      .post('/api/v1/auth/login')
      .send({})
      .expect(502)
      .expect({ statusCode: 502, message: 'Auth Service no disponible' });
  });

  it('alcanza los controladores de health y login mock de Auth por HTTP', async () => {
    await new Promise<void>((resolve) => upstream.close(() => resolve()));
    const authModule = await Test.createTestingModule({
      imports: [HealthModule, AuthModule],
    }).compile();
    const auth = authModule.createNestApplication();
    auth.setGlobalPrefix('api/v1');
    auth.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await auth.listen(Number(new URL(target).port), '127.0.0.1');
    try {
      const res = await request(gateway.getHttpServer())
        .get('/api/v1/auth/health')
        .expect(200);
      expect(res.body.service).toBe('auth-service');
      expect(res.body.status).toBe('ok');
      const login = await request(gateway.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'estudiante@alu.uct.cl', password: 'demo' })
        .expect(200);
      expect(login.body.accessToken).toEqual(expect.any(String));
      expect(login.body.user.email).toBe('estudiante@alu.uct.cl');
      expect(login.body.tokenType).toBe('Bearer');
      await request(gateway.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'invalido', password: 'demo' })
        .expect(400);
    } finally {
      await auth.close();
    }
  });
});
