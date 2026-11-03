// Run from the repository root. Requires real services and local Material author context.
// Creates one material and retains it for inspection; never changes moderation state.
const { mkdirSync, writeFileSync } = require('node:fs');
const { createHash } = require('node:crypto');
const assert = require('node:assert/strict');
const base = 'http://localhost:3000';
const output = process.env.E2E_OUTPUT || '/tmp/apuntes-e2e-263';
mkdirSync(output, { recursive: true });
const report = { startedAt: new Date().toISOString(), base, steps: [] };
let token;
async function call(name, path, options = {}) {
  const response = await fetch(base + path, {
    ...options, headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...options.headers },
    signal: AbortSignal.timeout(30000), redirect: 'error',
  });
  const bytes = Buffer.from(await response.arrayBuffer());
  const body = response.headers.get('content-type')?.includes('json') ? JSON.parse(bytes) : null;
  const saved = body && structuredClone(body);
  if (saved?.accessToken) saved.accessToken = '[REDACTED]';
  const step = { name, method: options.method || 'GET', url: base + path, status: response.status,
    body: saved, contentType: response.headers.get('content-type'), disposition: response.headers.get('content-disposition') };
  report.steps.push(step);
  console.log(name, response.status);
  return { body, bytes, step };
}
async function main() {
  await call('health', '/api/v1/health');
  const login = await call('login', '/api/v1/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: 'estudiante@alu.uct.cl', password: 'demo' }) });
  assert.equal(login.step.status, 200);
  token = login.body.accessToken;
  const tree = await call('catalog tree', '/api/v1/catalog');
  let chosen;
  for (const university of tree.body) for (const career of university.careers) for (const subject of career.subjects) {
    chosen ||= { university, career, subject };
  }
  assert.ok(chosen, 'Catalog must contain an active academic hierarchy');
  const { university, career, subject } = chosen;
  const professors = await call('professors', `/api/v1/catalog/professors?subjectId=${subject.id}`);
  report.academicIds = { universityId: university.id, careerId: career.id, subjectId: subject.id, professorId: professors.body[0]?.id };
  const title = `E2E263-${Date.now()}`;
  report.title = title;
  const pdf = Buffer.from('%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n');
  writeFileSync(`${output}/original.pdf`, pdf);
  report.originalSha256 = createHash('sha256').update(pdf).digest('hex');
  const form = new FormData();
  for (const [key, value] of Object.entries({ title, description: 'Real Gateway E2E issue 263', type: 'DOCUMENT', year: '2026', subjectId: subject.id, careerId: career.id, ...(professors.body[0] ? { professorId: professors.body[0].id } : {}) })) form.set(key, value);
  form.set('file', new Blob([pdf], { type: 'application/pdf' }), 'e2e-263.pdf');
  const created = await call('create', '/api/v1/materials', { method: 'POST', body: form });
  assert.equal(created.step.status, 201, JSON.stringify(created.body));
  const id = created.body.data.id;
  report.materialId = id;
  const list = await call('list', '/api/v1/materials?page=1&pageSize=100');
  list.step.containsCreated = list.body.items?.some(item => item.id === id) || false;
  const detail = await call('detail', `/api/v1/materials/${id}`);
  const download = await call('download', `/api/v1/materials/${id}/download`);
  if (download.step.status === 200) {
    writeFileSync(`${output}/download.pdf`, download.bytes);
    download.step.sha256 = createHash('sha256').update(download.bytes).digest('hex');
    download.step.matchesOriginal = download.bytes.equals(pdf);
  }
  const search = await call('search', `/api/v1/search?q=${encodeURIComponent(title)}`);
  search.step.containsCreated = search.body.results?.some(item => item.id === id) || false;
  const versions = await call('versions', `/api/v1/materials/${id}`);
  versions.step.hasVersions = versions.body.versions?.length > 0 || false;
  report.passed = list.step.containsCreated && detail.step.status === 200 && download.step.matchesOriginal === true && search.step.containsCreated && versions.step.hasVersions;
}
main().catch(error => { report.error = error.message; report.passed = false; }).finally(() => {
  writeFileSync(`${output}/report.json`, JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({ passed: report.passed, materialId: report.materialId, error: report.error, output }));
  if (!report.passed) process.exitCode = 1;
});
