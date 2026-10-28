/* Ejecutar desde backend/material-service. Solo para una BD de desarrollo/pruebas. */
const assert = require('node:assert/strict');
const { randomUUID, createHash } = require('node:crypto');
const { readFileSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { performance } = require('node:perf_hooks');

const fingerprint = (value) => createHash('sha256').update(value).digest('hex');
const save = (path, value) => writeFileSync(path, JSON.stringify(value, null, 2));

async function get(url) {
  const start = performance.now();
  try {
    const response = await fetch(url, {
      signal: AbortSignal.timeout(12000),
      headers: { accept: 'application/json' },
      redirect: 'error',
    });
    const raw = await response.text();
    const ms = Math.round((performance.now() - start) * 100) / 100;
    let body;
    try { body = JSON.parse(raw); } catch { body = { invalidJson: true }; }
    return { status: response.status, ms, body };
  } catch (error) {
    return {
      status: 0,
      ms: Math.round((performance.now() - start) * 100) / 100,
      body: { message: error.name === 'TimeoutError' ? 'Timeout del cliente (12 s)' : 'Fallo de conexión' },
    };
  }
}

function searchUrl(base, q, page = 1) {
  const url = new URL('/api/v1/search', base);
  url.search = new URLSearchParams({ q, page: String(page), pageSize: '20' }).toString();
  return url;
}

async function cleanup(prisma, manifest) {
  if (!Array.isArray(manifest.ids) || !manifest.ids.every((id) => typeof id === 'string') ||
      !/^searchprobe[a-f0-9]{32}$/.test(manifest.token)) {
    throw new Error('Manifiesto inválido; no se elimina ningún registro.');
  }
  const result = await prisma.material.deleteMany({
    where: {
      id: { in: manifest.ids },
      externalLink: `https://example.com/${manifest.token}`,
      versions: { none: {} },
    },
  });
  const remaining = await prisma.material.count({ where: { id: { in: manifest.ids } } });
  console.log(`Limpieza: ${result.count} materiales eliminados; ${remaining} pendientes.`);
  assert.equal(remaining, 0, 'Quedan registros de prueba; revisar antes de eliminar manualmente.');
}

async function run(prisma, options) {
  const runId = randomUUID().replaceAll('-', '');
  const token = `searchprobe${runId}`;
  const manifestPath = resolve(options.outputDir, `search-probe-${runId}.manifest.json`);
  const reportPath = resolve(options.outputDir, `search-probe-${runId}.report.json`);
  const manifest = { token, databaseFingerprint: options.databaseFingerprint, ids: [] };
  const report = { runId, startedAt: new Date().toISOString(), scenarios: [], cleaned: false };
  const created = [];
  console.log(`Manifiesto: ${manifestPath}`);
  console.log(`Informe: ${reportPath}`);
  save(manifestPath, manifest);
  save(reportPath, report);

  try {
    const baseline = await prisma.material.count({ where: { status: 'PUBLISHED' } });
    assert.ok(baseline >= 1 && baseline <= 100,
      'Esta prueba espera entre 1 y 100 publicados inicialmente. No modifica datos si no se cumple.');
    report.baseline = baseline;
    const template = await prisma.material.findFirst({ where: { status: 'PUBLISHED' } });
    const type = await prisma.materialType.findFirst({ where: { name: 'LINK', active: true } });
    assert.ok(template && type, 'Se requiere un material publicado y el tipo LINK activo.');
    const listUrl = new URL('/api/v1/materials?page=1&pageSize=100', options.materialBase);
    const initial = await get(listUrl);
    assert.equal(initial.status, 200, 'Material debe responder 200.');
    assert.equal(initial.body.total, baseline, 'La API y DATABASE_URL deben apuntar al mismo entorno.');
    // Verifica que los IDs visibles correspondan a esta misma BD antes de escribir.
    const localIds = new Set((await prisma.material.findMany({
      where: { status: 'PUBLISHED' }, select: { id: true },
    })).map((item) => item.id));
    assert.equal(initial.body.items.length, baseline);
    assert.ok(initial.body.items.every((item) => localIds.has(item.id)), 'La API usa otra BD.');
    for (const base of [options.directBase, options.gatewayBase]) {
      const check = await get(searchUrl(base, token));
      assert.equal(check.status, 200, `Search debe responder 200 antes de crear datos: ${JSON.stringify(check.body)}`);
      assert.equal(check.body.total, 0);
    }

    const startTime = Date.now();
    for (const target of [101, 501, 1001]) {
      const data = [];
      while (baseline + created.length + data.length < target) {
        const index = created.length + data.length;
        // Alterna coincidencias exclusivas en título y en descripción.
        data.push({
          id: randomUUID(),
          title: index % 2 === 0 ? `${token} material ${index}` : `Material temporal ${runId} ${index}`,
          description: index % 2 === 0 ? null : `Descripción ${token} ${index}`,
          externalLink: `https://example.com/${token}`,
          uploaderId: template.uploaderId,
          subjectId: template.subjectId,
          careerId: template.careerId,
          universityId: template.universityId,
          professorId: template.professorId,
          academicOfferingId: template.academicOfferingId,
          materialTypeId: type.id,
          academicYear: 2026,
          status: 'PUBLISHED',
          verified: false,
          createdAt: new Date(startTime + index),
        });
      }
      // Persistir IDs antes de escribir permite recuperar la limpieza tras una interrupción.
      manifest.ids.push(...data.map((item) => item.id));
      save(manifestPath, manifest);
      await prisma.material.createMany({ data });
      created.push(...data);
      const listed = await get(listUrl);
      assert.equal(listed.status, 200);
      assert.equal(listed.body.total, target, 'El conjunto cambió o la API apunta a otra BD.');
      const expectedIds = [...created].reverse().map((item) => item.id);
      const scenario = {
        published: target,
        materialPagesExpected: Math.ceil(target / 100),
        expectedMatches: created.length,
        measurements: [],
      };
      report.scenarios.push(scenario);
      console.log(`\n${target} publicados; ${scenario.materialPagesExpected} páginas esperadas; ${created.length} coincidencias.`);

      // Solicitudes secuenciales para no convertir esta comprobación en una prueba de carga.
      for (let attempt = 1; attempt <= 5; attempt += 1) {
        const pair = [];
        for (const [route, base] of [['direct', options.directBase], ['gateway', options.gatewayBase]]) {
          const result = await get(searchUrl(base, token));
          let valid = true;
          let validationError;
          try {
            assert.equal(result.status, 200);
            assert.equal(result.body.query, token);
            assert.equal(result.body.page, 1);
            assert.equal(result.body.pageSize, 20);
            assert.equal(result.body.total, created.length);
            assert.deepEqual(result.body.results.map((item) => item.id), expectedIds.slice(0, 20));
          } catch (error) { valid = false; validationError = error.message; }
          const measurement = { attempt, route, ...result, valid, validationError };
          scenario.measurements.push(measurement);
          pair.push(measurement);
          console.log(`${route} #${attempt}: HTTP ${result.status}, ${result.ms} ms, contrato=${valid ? 'OK' : 'FALLO'}`);
          save(reportPath, report);
        }
        if (pair.every((item) => item.valid)) {
          assert.deepEqual(pair[0].body, pair[1].body, 'Directo y Gateway difieren; mantener datos estables.');
        }
      }
      // Comprueba también la paginación final, además de medir la primera página.
      const second = await get(searchUrl(options.gatewayBase, token, 2));
      scenario.secondPage = second;
      save(reportPath, report);
      assert.equal(second.status, 200, 'Falló la segunda página por Gateway; revisar el informe.');
      assert.equal(second.body.page, 2);
      assert.equal(second.body.total, created.length);
      assert.deepEqual(second.body.results.map((item) => item.id), expectedIds.slice(20, 40));
      for (const route of ['direct', 'gateway']) {
        const measurements = scenario.measurements.filter((item) => item.route === route);
        const times = measurements.map((item) => item.ms).sort((a, b) => a - b);
        console.log(`${route}: mediana=${times[2]} ms; máximo=${times[4]} ms; correctas=${measurements.filter((item) => item.valid).length}/5`);
      }
    }
    report.passed = report.scenarios.every((scenario) => scenario.measurements.every((item) => item.valid));
    if (!report.passed) throw new Error('Hay respuestas fallidas; revisar el informe.');
  } catch (error) {
    report.passed = false;
    // No persistir errores Prisma que podrían contener información de conexión.
    report.failure = error.code ? `Error de base de datos (${error.code})` : error.message;
    throw error;
  } finally {
    try {
      await cleanup(prisma, manifest);
      report.cleaned = true;
    } finally { save(reportPath, report); }
  }
  return report;
}

async function main() {
  assert.ok(process.env.DATABASE_URL, 'Falta DATABASE_URL en .env de Material.');
  assert.notEqual(process.env.NODE_ENV, 'production', 'No ejecutar en producción.');
  assert.equal(process.env.SEARCH_PROBE_TEST_DATA, '1',
    'Configura SEARCH_PROBE_TEST_DATA=1 solo tras comprobar que DATABASE_URL es de desarrollo/pruebas.');
  const { PrismaClient } = require('.prisma/material-client');
  const prisma = new PrismaClient();
  const databaseFingerprint = fingerprint(process.env.DATABASE_URL);
  try {
    if (process.argv[2] === '--cleanup') {
      assert.ok(process.argv[3], 'Indica el archivo manifest.json.');
      const manifest = JSON.parse(readFileSync(resolve(process.argv[3]), 'utf8'));
      assert.equal(manifest.databaseFingerprint, databaseFingerprint, 'DATABASE_URL difiere del utilizado al crear los datos.');
      await cleanup(prisma, manifest);
    } else {
      assert.equal(process.argv.length, 2, 'Argumento desconocido.');
      await run(prisma, {
        databaseFingerprint,
        outputDir: process.cwd(),
        materialBase: process.env.PROBE_MATERIAL_URL || 'http://localhost:3003',
        directBase: process.env.PROBE_SEARCH_URL || 'http://localhost:3005',
        gatewayBase: process.env.PROBE_GATEWAY_URL || 'http://localhost:3000',
      });
    }
  } finally { await prisma.$disconnect(); }
}

module.exports = { run, cleanup };
if (require.main === module) {
  main().catch((error) => {
    console.error(error.code ? `Error de BD (${error.code}); revisar conexión y migraciones.` : error.message);
    process.exitCode = 1;
  });
}
