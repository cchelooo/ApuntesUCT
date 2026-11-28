import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { createServer, Server } from 'node:http';
import { AddressInfo } from 'node:net';
import { AppModule } from '../src/app.module';
import { configureRoutes } from '../src/configure-routes';
import { jwtSettings } from './authorization-fixture';

describe('Material: rechazo temprano de multipart sin token', () => {
  let app: INestApplication;
  let upstream: Server;
  let origin: string;
  const forwarded = jest.fn();

  beforeAll(async () => {
    upstream = createServer((req, res) => {
      forwarded();
      req.resume();
      res.writeHead(200).end('unexpected upstream request');
    });
    await new Promise<void>((resolve) =>
      upstream.listen(0, '127.0.0.1', resolve),
    );
    const upstreamUrl = `http://127.0.0.1:${(upstream.address() as AddressInfo).port}`;
    const settings = { ...jwtSettings, MATERIAL_SERVICE_URL: upstreamUrl };
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(ConfigService)
      .useValue({ get: (key: string) => settings[key] })
      .compile();
    app = module.createNestApplication();
    configureRoutes(app);
    await app.listen(0, '127.0.0.1');
    origin = await app.getUrl();
  });

  afterAll(async () => {
    await app?.close();
    await new Promise<void>((resolve) => upstream?.close(() => resolve()));
  });

  it('devuelve 401 sin reenviar el formulario a Material Service', async () => {
    const form = new FormData();
    form.set('title', 'Unauthorized smoke');
    form.set('year', '2026');
    form.set('type', 'LINK');
    form.set('subjectId', '11111111-1111-4111-8111-111111111111');
    form.set('externalLink', 'https://example.com');
    // Serialize this small fixture before sending: the assertion concerns the
    // Gateway's multipart authorization, not FormData's asynchronous writer.
    const encoded = new Response(form);
    const response = await fetch(`${origin}/api/v1/materials`, {
      method: 'POST',
      body: await encoded.arrayBuffer(),
      headers: {
        Connection: 'close',
        'Content-Type': encoded.headers.get('content-type')!,
      },
      signal: AbortSignal.timeout(5000),
    });
    expect(response.status).toBe(401);
    expect((await response.json()).statusCode).toBe(401);
    expect(forwarded).not.toHaveBeenCalled();
  });
});
