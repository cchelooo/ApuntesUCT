import { HttpAdapterHost } from '@nestjs/core';
import { ReportRoutingErrorFilter } from './reports/report-error.filter';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

export function setupApp(app: INestApplication): void {
  app.useGlobalFilters(new ReportRoutingErrorFilter(app.get(HttpAdapterHost).httpAdapter));
  app.setGlobalPrefix('api/v1', { exclude: ['health'] });
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
