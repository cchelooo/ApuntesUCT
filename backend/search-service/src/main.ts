import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { setupApp } from './setup-app';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  setupApp(app);

  const port = process.env.PORT || 3005;
  await app.listen(port);
  console.log(`Search Service ejecutándose en http://localhost:${port}`);
  console.log(`Documentación Swagger disponible en http://localhost:${port}/api/docs`);
}
void bootstrap();
