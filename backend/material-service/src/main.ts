import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { setupApp } from './setup-app';
import { HttpExceptionFilter } from './infrastructure/filters/http-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableShutdownHooks();
  app.useGlobalFilters(new HttpExceptionFilter());

  setupApp(app);

  const port = app.get(ConfigService).get<number>('port', 3003);
  await app.listen(port);
  console.log(`Material Service escuchando en http://localhost:${port}`);
  console.log(`Documentación OpenAPI en http://localhost:${port}/api/docs`);
  console.log(`Spec JSON en http://localhost:${port}/api/docs-json`);
}
void bootstrap();