import {
  MiddlewareConsumer,
  Module,
  NestModule,
  RequestMethod,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Request, Response } from 'express';
import { createProxyMiddleware, fixRequestBody } from 'http-proxy-middleware';

@Module({})
export class ProxyModule implements NestModule {
  constructor(private readonly config: ConfigService) {}

  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(
        createProxyMiddleware<Request, Response>({
          target:
            this.config.get<string>('AUTH_SERVICE_URL') ||
            'http://127.0.0.1:3001',
          changeOrigin: true,
          proxyTimeout: 5000,
          // Nest/Express puede quitar el punto de montaje de req.url.
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
        {
          path: 'auth/*path',
          method: RequestMethod.ALL,
        },
      );
  }
}
