import {
  MiddlewareConsumer,
  Module,
  NestModule,
  RequestMethod,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { serviceProxy } from './service-proxy';

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
  return serviceProxy(
    config.get<string>(urlKey) || defaultUrl,
    serviceName,
  );
}

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
