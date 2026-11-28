import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { test } from 'node:test';
import { checkUnauthorizedMaterial, expectStatus, request } from './smoke-http.mjs';

async function serverFor(t, handler) {
  const server = createServer(handler);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => {
    server.closeAllConnections();
    server.close(resolve);
  }));
  return `http://127.0.0.1:${server.address().port}`;
}

test('authorization probe sends POST without token or upload and accepts only 401', async t => {
  let received;
  const origin = await serverFor(t, (req, res) => {
    let bytes = 0;
    req.on('data', chunk => { bytes += chunk.length; });
    req.on('end', () => {
      received = { method: req.method, path: req.url, token: req.headers.authorization, bytes };
      res.writeHead(401).end('{"statusCode":401}');
    });
  });
  await checkUnauthorizedMaterial(origin);
  assert.deepEqual(received, { method: 'POST', path: '/api/v1/materials', token: undefined, bytes: 0 });
});

for (const status of [200, 400, 403, 500]) {
  test(`does not treat HTTP ${status} as an authentication rejection`, async t => {
    const origin = await serverFor(t, (_req, res) => res.writeHead(status).end());
    await assert.rejects(checkUnauthorizedMaterial(origin), { actual: status, expected: 401 });
  });
}

test('transport failure includes method, route and expected status, without accepting it as 401', async t => {
  const origin = await serverFor(t, req => req.socket.destroy());
  await assert.rejects(checkUnauthorizedMaterial(origin), error => {
    assert.match(error.message, /POST .*\/api\/v1\/materials: transport failure .*expected HTTP 401/);
    assert.ok(error.cause);
    return true;
  });
});

test('status-only checks consume the body; request preserves it for JSON assertions', async t => {
  const origin = await serverFor(t, (_req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end('{"ok":true}');
  });
  await expectStatus(origin, '/health');
  assert.deepEqual(await (await request(origin, '/detail')).json(), { ok: true });
});
