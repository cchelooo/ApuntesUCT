import assert from 'node:assert/strict';

export async function request(base, path, status = 200, options) {
  const target = new URL(path, base);
  const label = `${options?.method ?? 'GET'} ${target.origin}${target.pathname}`;
  let response;
  try {
    response = await fetch(target, {
      ...options,
      // Container recreation can invalidate idle keep-alive connections.
      headers: { Connection: 'close', ...options?.headers },
      signal: AbortSignal.timeout(15000),
    });
  } catch (cause) {
    const code = cause.cause?.code ?? cause.name;
    throw new Error(`${label}: transport failure (${code}); expected HTTP ${status}`, { cause });
  }
  if (response.status !== status) {
    await response.body?.cancel();
    assert.equal(response.status, status, label);
  }
  return response;
}

/** Consume responses whose only assertion is their HTTP status. */
export async function expectStatus(base, path, status = 200, options) {
  const response = await request(base, path, status, options);
  await response.arrayBuffer();
}

export async function checkUnauthorizedMaterial(base) {
  // Authorization precedes multipart parsing and the Material proxy. No upload
  // is needed here: an early rejection may close the socket during a FormData write.
  // Multipart rejection is covered separately by the Gateway HTTP regression test.
  await expectStatus(base, '/api/v1/materials', 401, { method: 'POST' });
}
