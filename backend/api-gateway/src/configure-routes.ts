import { INestApplication, RequestMethod } from '@nestjs/common';

export function configureRoutes(app: INestApplication): void {
  app.setGlobalPrefix('api/v1', {
    // Health expone una ruta raíz y conserva la URL versionada existente.
    exclude: [
      { path: 'health', method: RequestMethod.GET },
      { path: 'api/v1/health', method: RequestMethod.GET },
    ],
  });
}
