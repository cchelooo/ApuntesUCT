const { test } = require('node:test');
const assert = require('node:assert/strict');
const collection = require('../../docs/api/apuntesuct.postman_collection.json');
const environment = require('../../docs/api/apuntesuct.postman_environment.json');
const spec = require('../../docs/api/apuntesuct.openapi.json');
const items = collection.item.flatMap((folder) => folder.item);
const find = (method, path) =>
  items.find((item) => item.request.method === method && item.request.url.path.join('/') === path);

test('all requests use Gateway, variables resolve, and public routes are not duplicated', () => {
  const variables = new Set([...collection.variable, ...environment.values].map((v) => v.key));
  for (const item of items) {
    assert.ok(item.request.url.raw.startsWith('{{gatewayUrl}}/'));
    assert.ok(!item.request.url.raw.includes('/api/v1/api/v1/'));
    for (const match of JSON.stringify(item.request).matchAll(/\{\{(.*?)\}\}/g))
      assert.ok(variables.has(match[1]), match[1]);
  }
  for (const key of ['accessToken', 'materialId', 'versionId'])
    assert.ok(!environment.values.some((v) => v.key === key));
});

test('Material provides all five operations and usable multipart fields', () => {
  const upload = find('POST', 'api/v1/materials');
  const version = find('POST', 'api/v1/materials/{{materialId}}/versions');
  for (const item of [upload, version]) {
    assert.equal(item.request.body.mode, 'formdata');
    assert.ok(
      item.request.body.formdata.some((p) => p.key === 'file' && p.type === 'file' && !p.disabled),
    );
    assert.ok(!item.request.header.some((h) => h.key.toLowerCase() === 'content-type'));
  }
  for (const field of ['title', 'year', 'type', 'subjectId'])
    assert.ok(upload.request.body.formdata.some((p) => p.key === field && !p.disabled));
  assert.ok(find('GET', 'api/v1/materials'));
  assert.ok(find('GET', 'api/v1/materials/{{materialId}}'));
  const download = find('GET', 'api/v1/materials/{{materialId}}/download');
  assert.ok(download.request.url.query.some((p) => p.key === 'versionId' && p.disabled));
  assert.ok(!download.event[0].script.exec.join('\n').includes('to.be.json'));
});

test('Search documents real enums and filter dependencies', () => {
  const operation = spec.paths['/api/v1/search'].get;
  const parameters = Object.fromEntries(operation.parameters.map((p) => [p.name, p]));
  assert.deepEqual(parameters.sortBy.schema.enum, ['createdAt', 'title', 'year']);
  assert.ok(!parameters.type.schema.enum);
  assert.match(parameters.careerId.description, /universityId/);
  assert.match(parameters.professorId.description, /subjectId.*careerId.*universityId/);
  assert.ok(find('GET', 'api/v1/search'));
});

test('response examples preserve version history, pagination, error status and binary download', () => {
  for (const item of items.filter((i) => /materials|search/.test(i.request.url.raw))) {
    for (const response of item.response) {
      const body = JSON.parse(response.body);
      if (response.code >= 400) assert.equal(body.statusCode, response.code);
      if (body.page !== undefined) {
        assert.ok(body.page >= 1);
        assert.ok(body.pageSize >= 1 && body.pageSize <= 100);
      }
    }
  }
  const detail = JSON.parse(
    find('GET', 'api/v1/materials/{{materialId}}').response.find((r) => r.code === 200).body,
  );
  assert.deepEqual(detail.currentVersion, detail.versions[0]);
  assert.equal(typeof detail.currentVersion.fileSize, 'string');
  const operation = spec.paths['/api/v1/materials/{id}/versions'].post;
  assert.ok(operation.responses['201'].content['application/json'].schema);
  const download = spec.paths['/api/v1/materials/{id}/download'].get;
  assert.equal(
    download.responses['200'].content['application/octet-stream'].schema.format,
    'binary',
  );
  assert.ok(download.responses['404'].content['application/json']);
  for (const code of [401, 404, 413, 415, 502])
    assert.ok(items.some((i) => i.response.some((r) => r.code === code)));
});

test('all OpenAPI schema references resolve', () => {
  const walk = (object) => {
    if (!object || typeof object !== 'object') return;
    if (object.$ref) {
      const value = object.$ref
        .slice(2)
        .split('/')
        .reduce((o, key) => o?.[key], spec);
      assert.ok(value, object.$ref);
    }
    for (const value of Object.values(object)) walk(value);
  };
  walk(spec);
});
