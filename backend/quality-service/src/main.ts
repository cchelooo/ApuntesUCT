import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { setupApp } from './setup-app';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.enableShutdownHooks();
  setupApp(app);
  const port = app.get(ConfigService).getOrThrow<number>('quality.port');
  await app.listen(port, '0.0.0.0');
  console.log(`Quality Service escuchando en http://localhost:${port}`);
  console.log(`Salud: http://localhost:${port}/health`);
  console.log(`Swagger: http://localhost:${port}/api/docs`);
}
void bootstrap();
