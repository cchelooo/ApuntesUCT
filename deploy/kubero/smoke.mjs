import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const directory = fileURLToPath(new URL('.', import.meta.url));
const envFile = process.env.KUBERO_ENV_FILE ??
  `${directory}${existsSync(`${directory}.env`) ? '.env' : '.env.example'}`;
const compose = ['compose', '--env-file', envFile, '-f', `${directory}compose.yaml`];
const web = `http://127.0.0.1:${process.env.WEB_PORT ?? 18080}`;
const gateway = `http://127.0.0.1:${process.env.GATEWAY_PORT ?? 13000}`;

async function request(base, path, status = 200, options) {
  const response = await fetch(`${base}${path}`, {
    ...options,
    // Container recreation blocks this process while servers expire idle
    // keep-alive sockets. Use a fresh connection for each verification.
    headers: { Connection: 'close', ...options?.headers },
    signal: AbortSignal.timeout(15000),
  });
  assert.equal(response.status, status, `${base}${path}`);
  return response;
}

// Tokens travel over stdin, never command arguments or logs.
async function checkAuth(base) {
  const credentials = { email: `smoke-${randomUUID()}@alu.uct.cl`, password: randomUUID() };
  const registered = await (await request(base, '/api/v1/auth/register', 201, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: 'Kubero smoke', ...credentials }),
  })).json();
  try {
    assert.deepEqual(Object.keys(registered), ['user']);
    assert.deepEqual(Object.keys(registered.user).sort(), ['active', 'email', 'id', 'name', 'role']);
    assert.equal(registered.user.role, 'STUDENT');
    assert.equal(registered.user.active, true);
    const login = await (await request(base, '/api/v1/auth/login', 200, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(credentials),
    })).json();
    assert.deepEqual(login.user, registered.user);
    assert.equal(login.tokenType, 'Bearer');
    assert.equal(login.expiresIn, 3600);
    execFileSync('docker', [...compose, 'exec', '-T', 'auth', 'node', '-e', `
      const assert = require('node:assert/strict');
      const { readFileSync } = require('node:fs');
      const { createPublicKey } = require('node:crypto');
      const { verify } = require('jsonwebtoken');
      const input = JSON.parse(readFileSync(0, 'utf8'));
      const key = createPublicKey(readFileSync(process.env.JWT_PRIVATE_KEY_PATH));
      const claims = verify(input.token, key, {
        algorithms: ['RS256'], issuer: process.env.JWT_ISSUER, audience: process.env.JWT_AUDIENCE,
      });
      assert.equal(claims.sub, input.user.id);
      assert.equal(claims.email, input.user.email);
      assert.equal(claims.role, input.user.role);
      assert.equal(claims.exp - claims.iat, 3600);
      assert.equal(Object.hasOwn(claims, 'mock'), false);
    `], { input: JSON.stringify({ token: login.accessToken, user: registered.user }), stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 });
    await request(base, '/api/v1/auth/login', 401, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...credentials, password: 'incorrecta' }),
    });
  } finally {
    execFileSync('docker', [...compose, 'exec', '-T', 'auth', 'node', '-e', `
      const { PrismaClient } = require('.prisma/auth-client');
      const prisma = new PrismaClient();
      const email = require('node:fs').readFileSync(0, 'utf8');
      prisma.user.deleteMany({ where: { email } }).finally(() => prisma.$disconnect())
        .catch(error => { console.error(error.message); process.exitCode = 1; });
    `], { input: credentials.email, stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 });
  }
}

// Fixtures are written only to this Compose project's Material database and bucket.
// The public creation endpoint remains protected; this does not simulate Auth.
const id = randomUUID();
const title = `Kubero smoke ${id}`;
const content = '%PDF-1.4\nKubero deployment smoke\n%%EOF\n';
const fixture = `
const { PrismaClient } = require('.prisma/material-client');
const { Client } = require('minio');
const { createHash } = require('node:crypto');
const prisma = new PrismaClient();
const storage = new Client({
  endPoint: process.env.MINIO_ENDPOINT, port: Number(process.env.MINIO_PORT),
  useSSL: process.env.MINIO_USE_SSL === 'true',
  accessKey: process.env.MINIO_ACCESS_KEY, secretKey: process.env.MINIO_SECRET_KEY,
});
const id = ${JSON.stringify(id)};
const key = 'smoke/' + id;
const bucket = process.env.MINIO_BUCKET;
async function run() {
  if (process.argv[1] === 'cleanup') {
    await prisma.materialVersion.deleteMany({ where: { materialId: id } });
    await prisma.material.deleteMany({ where: { id } });
    await storage.removeObject(bucket, key);
    return;
  }
  const body = Buffer.from(${JSON.stringify(content)});
  await storage.putObject(bucket, key, body, body.length, { 'Content-Type': 'application/pdf' });
  const type = await prisma.materialType.findUniqueOrThrow({ where: { name: 'DOCUMENT' } });
  await prisma.material.create({ data: {
    id, uploaderId: id, subjectId: id, materialTypeId: type.id,
    title: ${JSON.stringify(title)}, academicYear: 2026, status: 'PUBLISHED',
    versions: { create: {
      versionNumber: 1, storageKey: key, originalFilename: 'kubero-smoke.pdf',
      mimeType: 'application/pdf', fileSize: BigInt(body.length),
      checksum: createHash('sha256').update(body).digest('hex'), createdBy: id,
    } },
  } });
}
run().finally(() => prisma.$disconnect()).catch(error => { console.error(error); process.exitCode = 1; });
`;
function materialFixture(action) {
  execFileSync('docker', [...compose, 'exec', '-T', 'material', 'node', '-e', fixture, action], {
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: 30000,
  });
}

await request(web, '/health');
const html = await (await request(web, '/materials/upload')).text();
assert.match(html, /<div id="root">/);
const asset = html.match(/src="(\/assets\/[^\"]+\.js)"/);
assert.ok(asset, 'Web serves the built React application');
const javascript = await (await request(web, asset[1])).text();
assert.ok(javascript.includes('/api/v1'), 'Web includes the relative Gateway URL');
assert.ok(!javascript.includes('http://localhost:3000'), 'No localhost API fallback in bundle');
await request(web, '/assets/missing-file.js', 404);
await request(web, '/api/v1/not-a-route', 404);

for (const base of [gateway, web]) {
  await request(base, '/api/v1/health');
  await request(base, '/api/v1/auth/health');
  const catalog = await (await request(base, '/api/v1/catalog')).json();
  assert.ok(Array.isArray(catalog));
  await checkAuth(base);
  const form = new FormData();
  form.set('title', 'Unauthorized smoke');
  form.set('year', '2026');
  form.set('type', 'LINK');
  form.set('subjectId', id);
  form.set('externalLink', 'https://example.com');
  await request(base, '/api/v1/materials', 401, { method: 'POST', body: form });
}

try {
  materialFixture('create');
  // Recreate the storage containers while keeping their named volumes. This
  // verifies disk persistence rather than merely reconnecting to a live process.
  execFileSync('docker', [...compose, 'up', '-d', '--force-recreate', '--no-deps', 'db-material', 'minio'], {
    stdio: ['ignore', 'pipe', 'pipe'], timeout: 60000,
  });
  execFileSync('docker', [...compose, 'up', '--wait', '--wait-timeout', '180'], {
    stdio: ['ignore', 'pipe', 'pipe'], timeout: 240000,
  });
  for (const base of [gateway, web]) {
    const list = await (await request(base, '/api/v1/materials?page=1&pageSize=100')).json();
    assert.ok(list.items.some(item => item.id === id), 'List returns the persisted material');
    const search = await (await request(base, `/api/v1/search?q=${encodeURIComponent(title)}`)).json();
    assert.ok(search.results.some(item => item.id === id), 'Search queries Catalog and Material');
    const absent = await (await request(base, `/api/v1/search?q=${randomUUID()}`)).json();
    assert.equal(absent.total, 0, 'An unrelated query does not return the fixture');
    const detail = await (await request(base, `/api/v1/materials/${id}`)).json();
    assert.equal(detail.id, id);
    assert.equal(detail.versions.length, 1);
    const download = await request(base, `/api/v1/materials/${id}/download`);
    assert.match(download.headers.get('content-disposition'), /kubero-smoke.pdf/);
    assert.equal(await download.text(), content, 'Download streams the actual MinIO object');
  }
  console.log('PASS: Web routes/assets, Gateway, real registration/login and RS256 verification, Catalog, list/search/detail/download after PostgreSQL and MinIO recreation, production creation guard.');
} finally {
  materialFixture('cleanup');
}
