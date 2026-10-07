const fs = require('node:fs');
const path = require('node:path');
const { Test } = require('@nestjs/testing');
const { DocumentBuilder, SwaggerModule } = require('@nestjs/swagger');

const BACKEND_ROOT = path.resolve(__dirname, '..');
const REPO_ROOT = path.resolve(BACKEND_ROOT, '..');
const OUTPUT_DIR = path.join(REPO_ROOT, 'docs', 'api');

const PRISMA_STUB = {
  $connect: async () => undefined,
  $disconnect: async () => undefined,
  $queryRaw: async () => [{ '?column?': 1 }],
  $queryRawUnsafe: async () => [],
};

const SERVICES = [
  {
    folder: 'API Gateway',
    appModule: 'api-gateway/dist/app.module.js',
    baseUrlVariable: 'gatewayUrl',
    title: 'API Gateway',
    description: 'Punto único de entrada a los microservicios de ApuntesUCT.',
    prismaModule: null,
  },
  {
    folder: 'Auth Service',
    appModule: 'auth-service/dist/src/app.module.js',
    prismaModule: 'auth-service/dist/src/infrastructure/prisma/prisma.service.js',
    baseUrlVariable: 'authUrl',
    title: 'Auth Service',
    description: 'Microservicio de identidad, autenticación, usuarios y roles.',
  },
  {
    folder: 'Catalog Service',
    appModule: 'catalog-service/dist/src/app.module.js',
    prismaModule: 'catalog-service/dist/src/infrastructure/prisma/prisma.service.js',
    baseUrlVariable: 'catalogUrl',
    title: 'Catalog Service',
    description: 'Microservicio de universidad, carrera, asignatura, profesor y sus relaciones.',
    bearer: true,
  },
];
const VARIABLES = [
  { key: 'gatewayUrl', value: 'http://localhost:3000' },
  { key: 'authUrl', value: 'http://localhost:3001' },
  { key: 'catalogUrl', value: 'http://localhost:3002' },
  { key: 'mockEmail', value: 'estudiante@alu.uct.cl' },
  { key: 'mockPassword', value: 'demo' },
  { key: 'accessToken', value: '', runtimeOnly: true },
  { key: 'universityId', value: '00000000-0000-4000-8000-000000000001' },
  { key: 'careerId', value: '00000000-0000-4000-8000-000000000002' },
  { key: 'subjectId', value: '00000000-0000-4000-8000-000000000003' },
  { key: 'professorId', value: '00000000-0000-4000-8000-000000000004' },
];

const BODY_VARIABLES = { email: 'mockEmail', password: 'mockPassword' };

const CATALOG_FILTER_PARAMETERS = [
  {
    name: 'universityId',
    description: 'Nivel 1. Sin requisito previo.',
    variable: 'universityId',
  },
  {
    name: 'careerId',
    description: 'Nivel 2. Requiere universityId.',
    variable: 'careerId',
  },
  {
    name: 'subjectId',
    description: 'Nivel 3. Requiere careerId.',
    variable: 'subjectId',
  },
  {
    name: 'professorId',
    description: 'Nivel 4. Requiere subjectId.',
    variable: 'professorId',
  },
];

async function loadDocument(service) {
  const appModulePath = path.join(BACKEND_ROOT, service.appModule);
  if (!fs.existsSync(appModulePath)) {
    throw new Error(
      `No existe ${service.appModule}. Compila los servicios con "npm run build" antes de exportar.`,
    );
  }

  const { AppModule } = require(appModulePath);
  const swaggerConfig = new DocumentBuilder()
    .setTitle(service.title)
    .setDescription(service.description)
    .setVersion('0.0.1')
    .addBearerAuth()
    .build();

  let testingModule = Test.createTestingModule({ imports: [AppModule] });
  if (service.prismaModule) {
    const { PrismaService } = require(path.join(BACKEND_ROOT, service.prismaModule));
    testingModule = testingModule.overrideProvider(PrismaService).useValue(PRISMA_STUB);
  }

  const compiled = await testingModule.compile();
  const app = compiled.createNestApplication();
  app.setGlobalPrefix('api/v1');
  await app.init();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  await app.close();
  return document;
}

function resolveRef(schema, components) {
  if (!schema?.$ref || !components) return schema;
  const name = schema.$ref.replace('#/components/schemas/', '');
  return components[name] ?? schema;
}

function sampleFromSchema(schema, components, seen = new Set()) {
  if (!schema) return 'string';
  if (schema.$ref) {
    const name = schema.$ref.replace('#/components/schemas/', '');
    if (seen.has(name)) return 'string';
    const next = new Set(seen);
    next.add(name);
    return sampleFromSchema(resolveRef(schema, components), components, next);
  }
  if (schema.example !== undefined) return schema.example;
  if (schema.default !== undefined) return schema.default;
  if (Array.isArray(schema.enum) && schema.enum.length) return schema.enum[0];
  if (schema.properties) {
    const sample = {};
    for (const [key, value] of Object.entries(schema.properties)) {
      sample[key] = sampleFromSchema(value, components, seen);
    }
    return sample;
  }
  if (schema.items) return [sampleFromSchema(schema.items, components, seen)];
  if (schema.type === 'integer' || schema.type === 'number') return 0;
  if (schema.type === 'boolean') return true;
  if (schema.format === 'date-time') return new Date(0).toISOString();
  if (schema.type === 'string' || !schema.type) return 'string';
  return 'string';
}

function expectedStatus(operation) {
  const codes = Object.keys(operation.responses ?? {});
  return codes.find((code) => /^2\d\d$/.test(code)) ?? codes[0] ?? '200';
}

function buildQuery(parameters, apiPath) {
  if (apiPath === '/api/v1/catalog/filter' && !parameters.length) {
    return CATALOG_FILTER_PARAMETERS.map((parameter) => ({
      key: parameter.name,
      value: `{{${parameter.variable}}}`,
      description: parameter.description,
    }));
  }
  return parameters
    .filter((parameter) => parameter.in === 'query')
    .map((parameter) => {
      const name = parameter.name;
      const value = VARIABLES.some((variable) => variable.key === name)
        ? `{{${name}}}`
        : sampleFromSchema(parameter.schema);
      return {
        key: name,
        value: String(value),
        description: parameter.description ?? '',
      };
    });
}

function buildHeaders(operation, components) {
  const headers = operation.parameters
    ? operation.parameters
        .filter((parameter) => parameter.in === 'header')
        .map((parameter) => ({
          key: parameter.name,
          value: sampleFromSchema(parameter.schema, components),
          description: parameter.description ?? '',
        }))
    : [];
  if (operation.requestBody) {
    headers.push({
      key: 'Content-Type',
      value: 'application/json',
      description: '',
    });
  }
  return headers;
}

function buildBody(operation, components) {
  if (!operation.requestBody) return undefined;
  const json = operation.requestBody.content?.['application/json'];
  if (!json) return undefined;
  const sample = sampleFromSchema(json.schema, components);
  const body = { ...sample };
  for (const [field, variable] of Object.entries(BODY_VARIABLES)) {
    if (field in body) body[field] = `{{${variable}}}`;
  }
  return {
    mode: 'raw',
    raw: JSON.stringify(body, null, 2),
    options: { raw: { language: 'json' } },
  };
}

function buildUrl(baseUrlVariable, apiPath, query) {
  const pathSegments = apiPath.split('/').filter(Boolean);
  const rawQuery = query
    .filter((parameter) => !parameter.disabled)
    .map((parameter) => `${parameter.key}=${parameter.value}`)
    .join('&');
  return {
    raw: `{{${baseUrlVariable}}}/${pathSegments.join('/')}${rawQuery ? `?${rawQuery}` : ''}`,
    host: [`{{${baseUrlVariable}}}`],
    path: pathSegments,
    ...(query.length ? { query } : {}),
  };
}

function buildTestEvent(status, { captureToken } = {}) {
  const exec = [
    `pm.test('Responde ${status}', function () { pm.response.to.have.status(${status}); });`,
    `pm.test('Devuelve JSON', function () { pm.response.to.be.json; });`,
  ];
  if (captureToken) {
    exec.push(
      `pm.test('Guarda el accessToken', function () {`,
      `  const json = pm.response.json();`,
      `  pm.expect(json.accessToken).to.be.a('string').and.not.empty;`,
      `  pm.collectionVariables.set('accessToken', json.accessToken);`,
      `});`,
    );
  }
  return [{ listen: 'test', script: { type: 'text/javascript', exec } }];
}

function buildItem({
  service,
  method,
  apiPath,
  operation,
  name,
  description,
  query,
  status,
  extraBody,
  components,
  bearer,
  captureToken,
}) {
  const requestBody = extraBody ?? buildBody(operation ?? {}, components);
  const headers = buildHeaders(operation ?? {}, components);
  if (extraBody) {
    headers.push({ key: 'Content-Type', value: 'application/json', description: '' });
  }
  if (bearer ?? service.bearer) {
    headers.push({
      key: 'Authorization',
      value: 'Bearer {{accessToken}}',
      description:
        'Token del login. Ningún endpoint lo exige todavía; queda para cuando exista auth real.',
    });
  }
  return {
    name,
    request: {
      method: method.toUpperCase(),
      header: headers,
      ...(requestBody ? { body: requestBody } : {}),
      url: buildUrl(service.baseUrlVariable, apiPath, query ?? []),
      description: description ?? operation?.description ?? `${apiPath} (${service.title})`,
    },
    response: [],
    event: buildTestEvent(status, { captureToken }),
  };
}

function collectItems(service, document) {
  const components = document.components?.schemas ?? {};
  const items = [];
  for (const [apiPath, pathItem] of Object.entries(document.paths ?? {})) {
    for (const method of ['get', 'post', 'put', 'patch', 'delete']) {
      const operation = pathItem[method];
      if (!operation) continue;
      const parameters = operation.parameters ?? [];
      const query = buildQuery(parameters, apiPath);
      const status = expectedStatus(operation);
      const name = operation.summary ?? `${method.toUpperCase()} ${apiPath}`;
      const captureToken = apiPath === '/api/v1/auth/login';

      if (apiPath === '/api/v1/catalog/filter') {
        items.push(
          buildItem({
            service,
            method,
            apiPath,
            operation,
            name: 'Filtro jerárquico del catálogo',
            description:
              `${operation.description ?? ''}\n\nOrden obligatorio (4 niveles): universityId → careerId → subjectId → professorId. Los tres primeros UUID salen de GET /api/v1/catalog o de los listados de selectores; el professorId no viene en ese árbol: se obtiene de GET /api/v1/catalog/professors o del arreglo professors de cada asignatura. year y type no forman parte del contrato de Catalog: pertenecen a Material/Search.`.trim(),
            query,
            status,
            components,
          }),
        );
        continue;
      }

      items.push(
        buildItem({
          service,
          method,
          apiPath,
          operation,
          name,
          query,
          status,
          components,
          captureToken,
          bearer: apiPath === '/api/v1/health' ? false : undefined,
        }),
      );
    }
  }
  return items;
}

const GATEWAY_PROXIED = [
  {
    method: 'get',
    apiPath: '/api/v1/auth/health',
    name: 'Health de Auth a través del gateway',
    description:
      'Ruta proxeada hacia Auth (no aparece en el OpenAPI del gateway porque el proxy es middleware). El gateway reescribe la ruta a /api/v1/health en Auth. Responde 502 si Auth no acepta la conexión o tarda más de 5 segundos.',
    query: [],
    status: '200',
  },
  {
    method: 'post',
    apiPath: '/api/v1/auth/login',
    name: 'Login mock a través del gateway',
    description:
      'Ruta proxeada hacia Auth (ver #91). Devuelve el JWT sin firma del login mock (#92) y guarda el accessToken en la variable accessToken. Responde 502 si Auth no está disponible.',
    query: [],
    status: '200',
    captureToken: true,
    extraBody: {
      mode: 'raw',
      raw: JSON.stringify({ email: '{{mockEmail}}', password: '{{mockPassword}}' }, null, 2),
      options: { raw: { language: 'json' } },
    },
  },
  {
    method: 'get',
    apiPath: '/api/v1/catalog',
    name: 'Árbol del catálogo a través del gateway',
    description:
      'Ruta proxeada hacia Catalog (ProxyModule, #122). No hay health reescrito para Catalog: su healthcheck está en {{catalogUrl}}/api/v1/health. Responde 502 con "Catalog Service no disponible" si Catalog no responde.',
    query: [],
    status: '200',
    bearer: true,
  },
  {
    method: 'get',
    apiPath: '/api/v1/catalog/filter',
    name: 'Filtro jerárquico a través del gateway',
    description:
      'Misma ruta proxeada hacia Catalog, con el prefijo jerárquico de 4 niveles (los tres primeros UUID de GET /api/v1/catalog o de los listados de selectores y el professorId de GET /api/v1/catalog/professors). year y type no forman parte del contrato de Catalog: pertenecen a Material/Search.',
    query: CATALOG_FILTER_PARAMETERS.map((parameter) => ({
      key: parameter.name,
      value: `{{${parameter.variable}}}`,
      description: parameter.description,
    })),
    status: '200',
    bearer: true,
  },
];

function disambiguateNames(folders) {
  const counts = new Map();
  for (const folder of folders) {
    for (const item of folder.item) {
      counts.set(item.name, (counts.get(item.name) ?? 0) + 1);
    }
  }
  for (const folder of folders) {
    for (const item of folder.item) {
      if (counts.get(item.name) > 1) {
        item.name = `${folder.name}: ${item.name}`;
      }
    }
  }
}

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const items = [];
  for (const service of SERVICES) {
    const document = await loadDocument(service);
    items.push({
      name: service.folder,
      description: service.description,
      item: [
        ...collectItems(service, document),
        ...(service.folder === 'API Gateway'
          ? GATEWAY_PROXIED.map((entry) => buildItem({ service, operation: {}, ...entry }))
          : []),
      ],
    });
  }

  disambiguateNames(items);

  const collection = {
    info: {
      name: 'ApuntesUCT API',
      description:
        'Colección generada desde el OpenAPI de api-gateway, auth-service y catalog-service (ver backend/scripts/export-postman-collection.cjs). Requiere los servicios levantados; auth y catalog necesitan su PostgreSQL. Importa también el environment apuntesuct.postman_environment.json.',
      schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
    },
    item: items,
    variable: VARIABLES.map((variable) => ({
      key: variable.key,
      value: variable.value,
      type: 'string',
    })),
  };

  const environment = {
    id: 'apuntesuct-local',
    name: 'ApuntesUCT local',
    // `runtimeOnly` no se exporta al environment: en Postman la variable de
    // environment tiene prioridad sobre la de colección, así que un valor vacío
    // en el environment taparía el accessToken que guarda el test del login.
    values: VARIABLES.filter((variable) => !variable.runtimeOnly).map((variable) => ({
      key: variable.key,
      value: variable.value,
      type: 'default',
      enabled: true,
    })),
    _postman_variable_scope: 'environment',
    _postman_exported_using: 'ApuntesUCT export-postman-collection.cjs',
  };

  const write = (file, data) => {
    const target = path.join(OUTPUT_DIR, file);
    fs.writeFileSync(target, `${JSON.stringify(data, null, 2)}\n`);
    console.log(`Escrito ${path.relative(REPO_ROOT, target)}`);
  };

  write('apuntesuct.postman_collection.json', collection);
  write('apuntesuct.postman_environment.json', environment);

  const requests = items.reduce((total, folder) => total + folder.item.length, 0);
  console.log(`Total: ${requests} peticiones en ${items.length} carpetas`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
