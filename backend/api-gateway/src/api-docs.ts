import { INestApplication } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

const SERVICES = [
  {
    name: 'API Gateway',
    description: 'Punto único de entrada a los microservicios de ApuntesUCT.',
    url: '/api/docs/gateway',
  },
  {
    name: 'Auth Service',
    description: 'Autenticación y gestión de usuarios.',
    url: 'http://localhost:3001/api/docs',
  },
  {
    name: 'Catalog Service',
    description: 'Catálogo de asignaturas y apuntes.',
    url: 'http://localhost:3002/api/docs',
  },
];

function renderDocsIndex(): string {
  const rows = SERVICES.map(
    (service) => `
    <tr>
      <td>${service.name}</td>
      <td>${service.description}</td>
      <td><a href="${service.url}">${service.url}</a></td>
    </tr>`,
  ).join('');

  return `<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>API Gateway — Documentación</title>
    <style>
      body { font-family: system-ui, sans-serif; margin: 0; padding: 2rem; background: #f5f6f8; color: #1f2937; }
      main { max-width: 48rem; margin: 0 auto; background: #fff; border: 1px solid #e5e7eb; border-radius: 0.5rem; padding: 2rem; }
      h1 { margin-top: 0; }
      a { color: #2563eb; text-decoration: none; }
      table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
      th, td { text-align: left; padding: 0.6rem 0.4rem; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
      th { color: #6b7280; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.05em; }
    </style>
  </head>
  <body>
    <main>
      <h1>API Gateway — Documentación</h1>
      <p>Documentación OpenAPI (Swagger) de los servicios del backend de ApuntesUCT.</p>
      <table>
        <thead>
          <tr><th>Servicio</th><th>Descripción</th><th>Documentación</th></tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
      <p>Servicios pendientes de implementación: material, quality y search.</p>
    </main>
  </body>
</html>`;
}

export function setupApiDocs(app: INestApplication): void {
  const swaggerConfig = new DocumentBuilder()
    .setTitle('API Gateway')
    .setDescription(
      'Punto único de entrada a los microservicios de ApuntesUCT.',
    )
    .setVersion('0.0.1')
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs/gateway', app, document);

  app
    .getHttpAdapter()
    .get('/api/docs', (_req, res) => res.send(renderDocsIndex()));
}