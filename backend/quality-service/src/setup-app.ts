import { QualityErrorFilter } from './infrastructure/moderation/quality-error.filter';
import { installModerationAudit } from './infrastructure/moderation/access-audit';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

export function setupApp(app: INestApplication): void {
  app.setGlobalPrefix('api/v1', { exclude: ['health'] });
  installModerationAudit(app, 'quality-service');
  app.useGlobalFilters(new QualityErrorFilter());
  app.useGlobalPipes(
    new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }),
  );
  const config = new DocumentBuilder()
    .setTitle('Quality Service')
    .setDescription(
      'Persistencia de moderación, verificación, calificaciones, reportes y favoritos. ' +
        'Las referencias a Material y Auth son lógicas. Las decisiones de Quality ' +
        'no modifican por sí solas el estado público ni verified de Material.',
    )
    .setVersion('0.0.1')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document, { jsonDocumentUrl: 'api/docs-json' });
}
