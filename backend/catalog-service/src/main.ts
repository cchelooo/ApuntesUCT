import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Habilitar CORS
  app.enableCors();

  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const swaggerConfig = new DocumentBuilder()
    .setTitle('Catalog Service')
    .setDescription(
      'Microservicio de universidad, carrera, asignatura, profesor y sus relaciones.',
    )
    .setVersion('0.0.1')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document, {
    jsonDocumentUrl: 'api/docs-json',
  });

  const port = process.env.PORT ?? 3002;
  await app.listen(port);
  console.log(`Catalog Service escuchando en http://localhost:${port}`);
  console.log(`Documentación OpenAPI en http://localhost:${port}/api/docs`);
  console.log(`Spec JSON en http://localhost:${port}/api/docs-json`);
}
void bootstrap();
