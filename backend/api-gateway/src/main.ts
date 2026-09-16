import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { setupApiDocs } from './api-docs';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);

  // Habilitar CORS
  app.enableCors();

  // Prefijo global /api/v1
  app.setGlobalPrefix('api/v1');

  // Validaciones globales de DTOs
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  setupApiDocs(app, configService);

  const port = configService.get<number>('PORT') || 3000;
  await app.listen(port);
  console.log(`🚀 API Gateway corriendo en: http://localhost:${port}/api/v1`);
  console.log(`Índice de documentación en http://localhost:${port}/api/docs`);
  console.log(`Swagger API Gateway en http://localhost:${port}/api/docs/gateway`);
}
bootstrap();
