// Read-only client scenario against an existing PUBLISHED test fixture.
// Quality approval and creation are deliberately outside this scenario.
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { mkdirSync, writeFileSync } = require('node:fs');
const base = 'http://localhost:3000';
const id = process.env.E2E_MATERIAL_ID;
const expectedHash = process.env.E2E_EXPECTED_SHA256;
const output = process.env.E2E_OUTPUT || '/tmp/apuntes-e2e-263-published';
const report = { startedAt: new Date().toISOString(), base, materialId: id,
  scenario: 'Public operations on a pre-existing PUBLISHED fixture; Quality approval not tested',
  expectedSha256: expectedHash, steps: [], passed: false };
async function get(name, path) {
  const res = await fetch(base + path, { redirect: 'error', signal: AbortSignal.timeout(30000) });
  const bytes = Buffer.from(await res.arrayBuffer());
  const body = res.headers.get('content-type')?.includes('json') ? JSON.parse(bytes) : null;
  const step = { name, url: base + path, status: res.status, body,
    contentType: res.headers.get('content-type'), contentDisposition: res.headers.get('content-disposition') };
  report.steps.push(step);
  assert.equal(res.status, 200, `${name}: ${JSON.stringify(body)}`);
  console.log(name, res.status);
  return { body, bytes, step };
}
async function main() {
  assert.match(id || '', /^[0-9a-f-]{36}$/i, 'Set E2E_MATERIAL_ID');
  assert.match(expectedHash || '', /^[0-9a-f]{64}$/i, 'Set independent E2E_EXPECTED_SHA256');
  const detail = await get('detail and versions', `/api/v1/materials/${id}`);
  assert.equal(detail.body.id, id);
  assert.equal(detail.body.status, 'PUBLISHED');
  assert.ok(detail.body.versions.length > 0);
  const version = detail.body.currentVersion;
  assert.equal(version.id, detail.body.versions[0].id);
  let found = false;
  for (let page = 1; page <= 100; page++) {
    const list = await get(`list page ${page}`, `/api/v1/materials?page=${page}&pageSize=100`);
    found = list.body.items.some(item => item.id === id);
    list.step.body = { total: list.body.total, page, containsFixture: found };
    if (found || page * 100 >= list.body.total) break;
  }
  assert.ok(found, 'Fixture must appear in public list');
  const query = new URLSearchParams({ universityId: detail.body.universityId, careerId: detail.body.careerId, subjectId: detail.body.subjectId });
  const catalog = await get('academic context', `/api/v1/catalog/filter?${query}`);
  assert.ok(catalog.body.some(subject => subject.id === detail.body.subjectId));
  const search = await get('search', `/api/v1/search?q=${encodeURIComponent(detail.body.title)}`);
  const hit = search.body.results.find(item => item.id === id);
  assert.ok(hit, 'Search must return the published fixture');
  assert.ok(hit.subjectName && hit.universityName, 'Search must enrich academic context');
  const download = await get('download current', `/api/v1/materials/${id}/download`);
  assert.equal(download.step.contentType, 'application/pdf');
  assert.match(download.step.contentDisposition, /^attachment;/);
  assert.equal(download.bytes.length, Number(version.fileSize));
  download.step.sha256 = createHash('sha256').update(download.bytes).digest('hex');
  assert.equal(download.step.sha256, expectedHash);
  writeFileSync(`${output}/download.pdf`, download.bytes);
  const selected = await get('download explicit version', `/api/v1/materials/${id}/download?versionId=${version.id}`);
  assert.deepEqual(selected.bytes, download.bytes);
  selected.step.matchesCurrentDownload = true;
  report.passed = true;
}
mkdirSync(output, { recursive: true });
main().catch(error => { report.error = error.message; process.exitCode = 1; }).finally(() => {
  writeFileSync(`${output}/report.json`, JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({ passed: report.passed, error: report.error, output }));
});
