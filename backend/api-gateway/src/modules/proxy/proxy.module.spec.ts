import { MiddlewareConsumer, RequestMethod } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

const mockCaptured: Array<Record<string, unknown>> = [];

jest.mock('http-proxy-middleware', () => ({
  createProxyMiddleware: (options: Record<string, unknown>) => {
    mockCaptured.push(options);
    return () => undefined;
  },
  fixRequestBody: jest.fn(),
}));

// El módulo se importa después de declarar el mock porque jest.mock se eleva por
// encima de los imports: sin este orden, createProxyMiddleware ya estaría
// resuelto cuando se registra el mock.
import { ProxyModule } from './proxy.module';

interface RouteSpec {
  path: string;
  method: number;
}

/** Consumer de Nest que registra en qué rutas se aplica cada middleware. */
function createConsumer(): {
  consumer: MiddlewareConsumer;
  routes: RouteSpec[];
} {
  const routes: RouteSpec[] = [];
  const consumer = {
    apply() {
      return {
        forRoutes(...specs: RouteSpec[]) {
          routes.push(...specs);
        },
      };
    },
  } as unknown as MiddlewareConsumer;
  return { consumer, routes };
}

/** Configura ProxyModule con un ConfigService que devuelve solo el env dado. */
function configure(env: Record<string, string | undefined> = {}) {
  mockCaptured.length = 0;
  const config = {
    get: (key: string) => env[key],
  } as unknown as ConfigService;
  const { consumer, routes } = createConsumer();
  new ProxyModule(config).configure(consumer);
  return { options: mockCaptured, routes };
}

describe('ProxyModule', () => {
  afterEach(() => {
    mockCaptured.length = 0;
  });

  describe('orígenes por defecto', () => {
    it.each([
      ['Auth', 'http://127.0.0.1:3001'],
      ['Catalog', 'http://127.0.0.1:3002'],
      ['Material', 'http://127.0.0.1:3003'],
      ['Search', 'http://127.0.0.1:3005'],
    ])('usa el puerto reservado de %s', (_label, expected) => {
      const { options } = configure();
      const targets = options.map((option) => String(option.target));
      expect(targets).toContain(expected);
    });

    it('no incluye Quality, que sigue sin enrutarse', () => {
      const { options } = configure();
      const targets = options.map((option) => String(option.target));
      expect(targets).not.toContain('http://127.0.0.1:3004');
      expect(targets.some((target) => target.includes('3004'))).toBe(false);
    });
  });

  describe('sobrescritura por variable de entorno', () => {
    it.each([
      ['AUTH_SERVICE_URL', 'http://auth.interno:9001', 'http://127.0.0.1:3001'],
      [
        'CATALOG_SERVICE_URL',
        'http://catalog.interno:9002',
        'http://127.0.0.1:3002',
      ],
      [
        'MATERIAL_SERVICE_URL',
        'http://material.interno:9003',
        'http://127.0.0.1:3003',
      ],
      [
        'SEARCH_SERVICE_URL',
        'http://search.interno:9005',
        'http://127.0.0.1:3005',
      ],
    ])('%s reemplaza el puerto reservado', (urlKey, override, reserved) => {
      const { options } = configure({ [urlKey]: override });
      const targets = options.map((option) => String(option.target));
      expect(targets).toContain(override);
      expect(targets).not.toContain(reserved);
    });

    it('una variable vacía cae al puerto reservado', () => {
      const { options } = configure({ MATERIAL_SERVICE_URL: '' });
      const targets = options.map((option) => String(option.target));
      expect(targets).toContain('http://127.0.0.1:3003');
    });
  });

  describe('contrato compartido', () => {
    it.each([
      ['Material', 'MATERIAL_SERVICE_URL', 'http://127.0.0.1:3003'],
      ['Search', 'SEARCH_SERVICE_URL', 'http://127.0.0.1:3005'],
    ])(
      '%s fija timeout de 5 s, changeOrigin y fixRequestBody',
      (_label, urlKey, expected) => {
        const { options } = configure();
        const option = options.find((item) => item.target === expected);

        expect(option).toBeDefined();
        expect(option?.proxyTimeout).toBe(5000);
        expect(option?.changeOrigin).toBe(true);
        expect(option?.on).toHaveProperty('proxyReq');
      },
    );

    it.each([
      ['Material', 'MATERIAL_SERVICE_URL', 'http://127.0.0.1:3003', 'Material Service'],
      ['Search', 'SEARCH_SERVICE_URL', 'http://127.0.0.1:3005', 'Search Service'],
    ])(
      '%s responde 502 con su propio mensaje cuando el destino falla',
      (_label, _urlKey, target, serviceName) => {
        const { options } = configure();
        const option = options.find((item) => item.target === target);
        const on = option?.on as {
          error: (err: Error, req: unknown, res: unknown) => void;
        };

        const writeHead = jest.fn();
        const end = jest.fn();
        on.error(new Error('ECONNREFUSED'), {}, { writeHead, end, headersSent: false });

        expect(writeHead).toHaveBeenCalledWith(502, {
          'Content-Type': 'application/json',
        });
        expect(end).toHaveBeenCalledWith(
          JSON.stringify({
            statusCode: 502,
            message: `${serviceName} no disponible`,
          }),
        );
      },
    );

    it.each([
      ['Material', 'MATERIAL_SERVICE_URL', 'http://127.0.0.1:3003'],
      ['Search', 'SEARCH_SERVICE_URL', 'http://127.0.0.1:3005'],
    ])(
      '%s no intenta responder si ya se enviaron cabeceras',
      (_label, _urlKey, target) => {
        const { options } = configure();
        const option = options.find((item) => item.target === target);
        const on = option?.on as {
          error: (err: Error, req: unknown, res: unknown) => void;
        };

        const writeHead = jest.fn();
        const end = jest.fn();
        on.error(new Error('ECONNRESET'), {}, { writeHead, end, headersSent: true });

        expect(writeHead).not.toHaveBeenCalled();
        expect(end).not.toHaveBeenCalled();
      },
    );
  });

  describe('rutas capturadas', () => {
    it.each([
      ['Material', 'materials'],
      ['Search', 'search'],
    ])('%s captura %s y sus subrutas con todos los métodos', (_label, path) => {
      const { routes } = configure();
      const paths = routes.filter((route) => route.path.startsWith(path));

      expect(paths.map((route) => route.path).sort()).toEqual(
        [path, `${path}/*path`].sort(),
      );
      expect(paths.every((route) => route.method === RequestMethod.ALL)).toBe(
        true,
      );
    });

    it('sigue capturando auth y catalog además de materials y search', () => {
      const { routes } = configure();
      const paths = routes.map((route) => route.path);

      expect(paths).toEqual(
        expect.arrayContaining([
          'auth',
          'auth/*path',
          'catalog',
          'catalog/*path',
          'materials',
          'materials/*path',
          'search',
          'search/*path',
        ]),
      );
    });
  });
});
