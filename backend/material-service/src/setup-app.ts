import { installModerationAudit } from './infrastructure/moderation/access-audit';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { HttpExceptionFilter } from './infrastructure/filters/http-exception.filter';

export function setupApp(app: INestApplication): void {
  app.enableCors();
  app.setGlobalPrefix('api/v1', { exclude: ['internal/v1/quality/{*path}'] });
  installModerationAudit(app, 'material-service');
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
  );

  const swaggerConfig = new DocumentBuilder()
    .setTitle('Material Service')
    .setDescription('Microservicio de materiales académicos.')
    .setVersion('0.0.1')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document, {
    jsonDocumentUrl: 'api/docs-json',
  });
}
