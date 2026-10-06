import {
  MiddlewareConsumer,
  Module,
  NestModule,
  RequestMethod,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { serviceProxy } from './service-proxy';

@Module({})
export class ProxyModule implements NestModule {
  constructor(private readonly config: ConfigService) {}

  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(
        serviceProxy(
          this.config.get<string>('AUTH_SERVICE_URL') ||
            'http://127.0.0.1:3001',
          'Auth Service',
          (path) =>
            path.replace(
              /^\/api\/v1\/auth\/health\/?(?=\?|$)/,
              '/api/v1/health',
            ),
        ),
      )
      .forRoutes(
        { path: 'auth', method: RequestMethod.ALL },
        { path: 'auth/*path', method: RequestMethod.ALL },
      );

    consumer
      .apply(
        serviceProxy(
          this.config.get<string>('CATALOG_SERVICE_URL') ||
            'http://127.0.0.1:3002',
          'Catalog Service',
        ),
      )
      .forRoutes(
        { path: 'catalog', method: RequestMethod.ALL },
        { path: 'catalog/*path', method: RequestMethod.ALL },
      );
  }
}
