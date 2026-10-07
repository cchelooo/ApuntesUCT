import { MiddlewareConsumer, RequestMethod } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

const mockCaptured: Array<Record<string, unknown>> = [];

const mockWeb = jest.fn();
jest.mock('httpxy', () => ({
  createProxyServer: (options: Record<string, unknown>) => {
    mockCaptured.push(options);
    return { web: mockWeb };
  },
}));

import { ProxyModule } from './proxy.module';
import { serviceProxy } from './service-proxy';
import type { Request, Response } from 'express';

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
      '%s fija timeout de 5 s, y changeOrigin',
      (_label, urlKey, expected) => {
        const { options } = configure();
        const option = options.find((item) => item.target === expected);

        expect(option).toBeDefined();
        expect(option?.proxyTimeout).toBe(5000);
        expect(option?.changeOrigin).toBe(true);
      },
    );

    it.each([
      ['Material Service', false],
      ['Search Service', false],
      ['Material Service', true],
      ['Search Service', true],
    ])('maneja el fallo de %s con headersSent=%s', async (serviceName, headersSent) => {
      mockWeb.mockRejectedValueOnce(new Error('ECONNRESET'));
      const middleware = serviceProxy('http://upstream', serviceName);
      const req = { originalUrl: '/api/v1/materials', headers: {} } as Request;
      const res = {
        headersSent,
        destroyed: false,
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
        destroy: jest.fn(),
      };
      middleware(req, res as unknown as Response, jest.fn());
      await Promise.resolve();
      if (headersSent) {
        expect(res.destroy).toHaveBeenCalled();
        expect(res.status).not.toHaveBeenCalled();
        expect(res.json).not.toHaveBeenCalled();
      } else {
        expect(res.status).toHaveBeenCalledWith(502);
        expect(res.json).toHaveBeenCalledWith({ statusCode: 502, message: `${serviceName} no disponible` });
      }
    });
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
