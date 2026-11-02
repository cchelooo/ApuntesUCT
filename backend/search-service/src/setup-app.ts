import { INestApplication, ValidationPipe } from '@nestjs/common';
import { setupSwagger } from './setup-swagger';

/** Configuración compartida por el arranque real y las pruebas HTTP. */
export function setupApp(app: INestApplication): void {
  app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true }));

  // Los controladores ya incluyen api/v1. No agregar otro prefijo global.
  setupSwagger(app);
}
