import {
  MiddlewareConsumer,
  Module,
  NestModule,
  RequestMethod,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request, Response } from 'express';
import { createProxyMiddleware, fixRequestBody } from 'http-proxy-middleware';

interface ServiceProxyOptions {
  /** Variable de entorno que sobrescribe el origen del servicio. */
  urlKey: string;
  /** Origen usado cuando la variable de entorno no está definida. */
  defaultUrl: string;
  /** Nombre legible del servicio, usado en el mensaje de error 502. */
  serviceName: string;
}

/**
 * Construye el proxy de un microservicio con el contrato compartido por
 * Catalog, Material y Search: conserva método, query, cuerpo, Authorization y
 * cookies, y responde 502 si el servicio no está disponible.
 */
function createServiceProxy(
  config: ConfigService,
  { urlKey, defaultUrl, serviceName }: ServiceProxyOptions,
) {
  return createProxyMiddleware<Request, Response>({
    target: config.get<string>(urlKey) || defaultUrl,
    changeOrigin: true,
    proxyTimeout: 5000,
    on: {
      proxyReq: fixRequestBody,
      error: (_error, _req, res) => {
        if ('writeHead' in res && !res.headersSent) {
          res.writeHead(502, { 'Content-Type': 'application/json' });
          res.end(
            JSON.stringify({
              statusCode: 502,
              message: `${serviceName} no disponible`,
            }),
          );
        }
      },
    },
  });
}

@Module({})
export class ProxyModule implements NestModule {
  constructor(private readonly config: ConfigService) {}

  configure(consumer: MiddlewareConsumer) {
    // 1. Proxy para Auth Service
    consumer
      .apply(
        createProxyMiddleware<Request, Response>({
          target:
            this.config.get<string>('AUTH_SERVICE_URL') ||
            'http://127.0.0.1:3001',
          changeOrigin: true,
          proxyTimeout: 5000,
          pathRewrite: (_path, req) =>
            req.originalUrl.replace(
              /^\/api\/v1\/auth\/health\/?(?=\?|$)/,
              '/api/v1/health',
            ),
          on: {
            proxyReq: fixRequestBody,
            error: (_error, _req, res) => {
              if ('writeHead' in res && !res.headersSent) {
                res.writeHead(502, { 'Content-Type': 'application/json' });
                res.end(
                  JSON.stringify({
                    statusCode: 502,
                    message: 'Auth Service no disponible',
                  }),
                );
              }
            },
          },
        }),
      )
      .forRoutes(
        { path: 'auth', method: RequestMethod.ALL },
        { path: 'auth/*path', method: RequestMethod.ALL },
      );

    // 2. Proxy para Catalog Service (Añadido para habilitar /api/v1/catalog)
    consumer
      .apply(
        createServiceProxy(this.config, {
          urlKey: 'CATALOG_SERVICE_URL',
          defaultUrl: 'http://127.0.0.1:3002',
          serviceName: 'Catalog Service',
        }),
      )
      .forRoutes(
        { path: 'catalog', method: RequestMethod.ALL },
        { path: 'catalog/*path', method: RequestMethod.ALL },
      );

    // 3. Proxy para Material Service (habilita /api/v1/materials)
    consumer
      .apply(
        createServiceProxy(this.config, {
          urlKey: 'MATERIAL_SERVICE_URL',
          defaultUrl: 'http://127.0.0.1:3003',
          serviceName: 'Material Service',
        }),
      )
      .forRoutes(
        { path: 'materials', method: RequestMethod.ALL },
        { path: 'materials/*path', method: RequestMethod.ALL },
      );

    // 4. Proxy para Search Service (habilita /api/v1/search)
    consumer
      .apply(
        createServiceProxy(this.config, {
          urlKey: 'SEARCH_SERVICE_URL',
          defaultUrl: 'http://127.0.0.1:3005',
          serviceName: 'Search Service',
        }),
      )
      .forRoutes(
        { path: 'search', method: RequestMethod.ALL },
        { path: 'search/*path', method: RequestMethod.ALL },
      );
  }
}