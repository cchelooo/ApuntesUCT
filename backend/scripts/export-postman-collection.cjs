const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');
const { Test } = createRequire(path.resolve(__dirname, '../api-gateway/package.json'))(
  '@nestjs/testing',
);
const { addExamples } = require('./api-examples.cjs');
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
    baseUrlVariable: 'gatewayUrl',
    title: 'Auth Service',
    description: 'Microservicio de identidad, autenticación, usuarios y roles.',
  },
  {
    folder: 'Catalog Service',
    appModule: 'catalog-service/dist/src/app.module.js',
    prismaModule: 'catalog-service/dist/src/infrastructure/prisma/prisma.service.js',
    baseUrlVariable: 'gatewayUrl',
    title: 'Catalog Service',
    description: 'Microservicio de universidad, carrera, asignatura, profesor y sus relaciones.',
    bearer: true,
  },
];
SERVICES.push(
  {
    folder: 'Material Service',
    appModule: 'material-service/dist/app.module.js',
    prismaModule: 'material-service/dist/infrastructure/prisma/prisma.service.js',
    baseUrlVariable: 'gatewayUrl',
    title: 'Material Service',
  },
  {
    folder: 'Search Service',
    appModule: 'search-service/dist/app.module.js',
    baseUrlVariable: 'gatewayUrl',
    title: 'Search Service',
  },
);
const VARIABLES = [
  { key: 'gatewayUrl', value: 'http://localhost:3000' },
  { key: 'resourceId', value: '' },
  { key: 'materialId', value: '', runtimeOnly: true },
  { key: 'versionId', value: '', runtimeOnly: true },
  { key: 'mockEmail', value: 'estudiante@alu.uct.cl' },
  { key: 'mockPassword', value: '' },
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

  if (service.folder === 'Auth Service') {
    const { AccessTokenService } = require(path.join(BACKEND_ROOT, 'auth-service/dist/src/infrastructure/security/access-token.service.js'));
    testingModule = testingModule.overrideProvider(AccessTokenService).useValue({});
  }
  if (service.folder === 'Material Service') {
    const { ObjectStorage } = require(
      path.join(BACKEND_ROOT, 'material-service/dist/application/ports/object-storage.port.js'),
    );
    testingModule = testingModule.overrideProvider(ObjectStorage).useValue({});
  }
  const compiled = await testingModule.compile();
  const app = compiled.createNestApplication();
  if (service.folder === 'API Gateway') {
    require(path.join(BACKEND_ROOT, 'api-gateway/dist/configure-routes.js')).configureRoutes(app);
  } else if (service.folder !== 'Search Service') {
    app.setGlobalPrefix(
      'api/v1',
      service.folder === 'Catalog Service' ? { exclude: ['health'] } : {},
    );
  }
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
  if (schema.allOf)
    return Object.assign(
      {},
      ...schema.allOf.map((part) => sampleFromSchema(part, components, seen)),
    );
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
  if (schema.nullable) return null;
  if (schema.items) return [];
  if (schema.format === 'uuid') return '00000000-0000-4000-8000-000000000001';
  if (schema.type === 'integer' || schema.type === 'number') return schema.minimum ?? 0;
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
        description: [
          parameter.description,
          parameter.schema?.enum ? `Valores: ${parameter.schema.enum.join(', ')}` : '',
        ]
          .filter(Boolean)
          .join(' '),
        disabled:
          !parameter.required && !['q', 'page', 'pageSize', 'sortBy', 'order'].includes(name),
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
  if (operation.requestBody?.content?.['application/json']) {
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
  const multipart = operation.requestBody.content?.['multipart/form-data'];
  if (multipart) {
    const schema = resolveRef(multipart.schema, components);
    return {
      mode: 'formdata',
      formdata: Object.entries(schema.properties ?? {}).map(([key, property]) => ({
        key,
        type: property.format === 'binary' ? 'file' : 'text',
        ...(property.format === 'binary'
          ? { src: [] }
          : {
              value: ['subjectId', 'careerId', 'professorId'].includes(key)
                ? `{{${key}}}`
                : String(sampleFromSchema(property, components)),
            }),
        description: property.description ?? '',
        disabled: key !== 'file' && !(schema.required ?? []).includes(key),
      })),
    };
  }
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
  const pathSegments = apiPath
    .replace(/\{id\}/g, apiPath.includes('/materials') ? '{{materialId}}' : '{{resourceId}}')
    .split('/')
    .filter(Boolean);
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

function buildTestEvent(status, { captureToken, binary } = {}) {
  const exec = [
    `pm.test('Responde ${status}', function () { pm.response.to.have.status(${status}); });`,
    ...(binary
      ? [
          `pm.test('Descarga adjunta', function () { pm.expect(pm.response.headers.get('Content-Disposition')).to.include('attachment'); });`,
        ]
      : [`pm.test('Devuelve JSON', function () { pm.response.to.be.json; });`]),
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
      description: 'Token del login; Catalog actualmente no lo valida.',
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
    event: buildTestEvent(status, { captureToken, binary: apiPath.endsWith('/download') }),
  };
}

function collectItems(service, document) {
  const components = document.components?.schemas ?? {};
  const items = [];
  for (const [apiPath, pathItem] of Object.entries(document.paths ?? {})) {
    for (const method of ['get', 'post', 'put', 'patch', 'delete']) {
      const operation = pathItem[method];
      if (!operation) continue;
      if (
        service.folder !== 'API Gateway' &&
        !apiPath.startsWith('/api/v1/auth') &&
        !apiPath.startsWith('/api/v1/catalog') &&
        !apiPath.startsWith('/api/v1/materials') &&
        !apiPath.startsWith('/api/v1/search')
      )
        continue;
      const parameters = operation.parameters ?? [];
      const query = buildQuery(parameters, apiPath);
      for (const parameter of query) {
        if (parameter.key === 'versionId') parameter.value = '{{versionId}}';
      }
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
  for (const item of items) {
    const route = item.request.url.path
      .join('/')
      .replace('{{materialId}}', '{id}')
      .replace('{{resourceId}}', '{id}');
    const operation = document.paths['/' + route]?.[item.request.method.toLowerCase()];
    for (const [code, response] of Object.entries(operation?.responses ?? {})) {
      const json = response.content?.['application/json'];
      if (!json?.schema) continue;
      item.response.push({
        name: `${code} — ejemplo ilustrativo`,
        originalRequest: item.request,
        status: response.description,
        code: Number(code),
        header: [{ key: 'Content-Type', value: 'application/json' }],
        body: JSON.stringify(json.example ?? sampleFromSchema(json.schema, components), null, 2),
      });
    }
    if (service.folder !== 'API Gateway') {
      item.response.push({
        name: '502 — destino Gateway no disponible',
        originalRequest: item.request,
        status: 'Bad Gateway',
        code: 502,
        header: [{ key: 'Content-Type', value: 'application/json' }],
        body: JSON.stringify(
          { statusCode: 502, message: `${service.title} no disponible` },
          null,
          2,
        ),
      });
    }
    if (route === 'api/v1/materials' && item.request.method === 'GET') {
      item.event[0].script.exec.push(
        "if (pm.response.code === 200) { const first = pm.response.json().items[0]; if (first) pm.collectionVariables.set('materialId', first.id); }",
      );
    }
    if (route === 'api/v1/materials/{id}' && item.request.method === 'GET') {
      item.event[0].script.exec.push(
        "if (pm.response.code === 200) { const v = pm.response.json().currentVersion; pm.collectionVariables.set('versionId', v ? v.id : ''); }",
      );
    }
  }
  return items;
}

const GATEWAY_PROXIED = [
  {
    method: 'get',
    apiPath: '/api/v1/auth/health',
    name: 'Health de Auth mediante Gateway',
    description: 'Gateway reescribe a /api/v1/health de Auth. Si Auth no responde devuelve 502.',
    query: [],
    status: '200',
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
  const publicSpec = {
    openapi: '3.0.0',
    info: { title: 'ApuntesUCT — API pública', version: '1.0.0' },
    servers: [
      {
        url: 'http://localhost:3000',
        description: 'Gateway local; reemplazar por el host desplegado',
      },
    ],
    paths: {},
    components: { schemas: {}, securitySchemes: { bearer: { type: 'http', scheme: 'bearer' } } },
  };
  for (const service of SERVICES) {
    const document = await loadDocument(service);
    addExamples(service.folder, document);
    // Prefix schemas to avoid collisions between independently generated service documents.
    const prefix = service.folder.replaceAll(' ', '');
    const renamed = JSON.parse(
      JSON.stringify(document).replaceAll(
        '#/components/schemas/',
        `#/components/schemas/${prefix}_`,
      ),
    );
    for (const [name, schema] of Object.entries(renamed.components?.schemas ?? {}))
      publicSpec.components.schemas[`${prefix}_${name}`] = schema;
    for (const [route, pathItem] of Object.entries(renamed.paths)) {
      const publicRoute =
        service.folder === 'Auth Service' && route === '/api/v1/health'
          ? '/api/v1/auth/health'
          : route;
      if (
        service.folder === 'API Gateway' ||
        /^\/api\/v1\/(auth|catalog|materials|search)(\/|$)/.test(publicRoute)
      ) {
        for (const operation of Object.values(pathItem))
          if (operation.operationId) operation.operationId = `${prefix}_${operation.operationId}`;
        publicSpec.paths[publicRoute] = pathItem;
      }
    }
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
        'API pública mediante Gateway. Generada desde los cinco servicios. Ver docs/api/README.md y docs/api/integracion-material-search.md para requisitos, autenticación temporal y ejemplos. Los ejemplos son ilustrativos, no capturas de producción.',
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

  for (const [route, pathItem] of Object.entries(publicSpec.paths)) {
    for (const operation of Object.values(pathItem)) {
      if (!operation.responses) continue;
      if (route === '/health' || route === '/api/v1/health') continue;
      const previous = operation.responses['502'];
      const schema = previous?.content?.['application/json']?.schema;
      const proxySchema = {
        type: 'object',
        required: ['statusCode', 'message'],
        properties: { statusCode: { type: 'integer', enum: [502] }, message: { type: 'string' } },
      };
      operation.responses['502'] = {
        description:
          `${previous?.description ?? ''} Gateway devuelve { statusCode: 502, message: '<servicio> Service no disponible' } si el destino no responde.`.trim(),
        content: {
          'application/json': { schema: schema ? { anyOf: [schema, proxySchema] } : proxySchema },
        },
      };
    }
  }
  write('apuntesuct.openapi.json', publicSpec);
  write('apuntesuct.postman_collection.json', collection);
  write('apuntesuct.postman_environment.json', environment);

  const requests = items.reduce((total, folder) => total + folder.item.length, 0);
  console.log(`Total: ${requests} peticiones en ${items.length} carpetas`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
