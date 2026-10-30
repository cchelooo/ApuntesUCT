import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

/** Configuración compartida por el arranque real y las pruebas HTTP. */
export function setupApp(app: INestApplication): void {
  app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true }));

  const config = new DocumentBuilder()
    .setTitle('Search Service API')
    .setDescription('Microservicio de búsqueda y consulta desacoplada para ApuntesUCT')
    .setVersion('1.0')
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'JWT-auth')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  // Los controladores ya incluyen api/v1. No agregar otro prefijo global.
  SwaggerModule.setup('api/docs', app, document);
}
