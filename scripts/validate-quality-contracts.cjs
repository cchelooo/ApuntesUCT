// Validaciones documentales del contrato. No ejecuta endpoints ni prueba autorización real.
// Node.js; sin paquetes adicionales. Ejecutar desde cualquier directorio.
const assert = require('node:assert/strict');
const { readFileSync, existsSync } = require('node:fs');
const { resolve, dirname } = require('node:path');

const root = resolve(__dirname, '..');
const files = [
  'docs/api/quality.openapi.json',
  'docs/api/material-quality-internal.openapi.json',
];
const states = ['PENDING_REVIEW', 'PUBLISHED', 'REJECTED', 'RETIRED'];
const roles = new Set(['STUDENT', 'MODERATOR', 'ADMIN']);
let checks = 0;
function check(condition, message) {
  checks += 1;
  assert.ok(condition, message);
}
function pointer(doc, value) {
  check(value.startsWith('#/'), `Referencia no local: ${value}`);
  let result = doc;
  for (const part of value.slice(2).split('/')) {
    const key = part.replace(/~1/g, '/').replace(/~0/g, '~');
    check(result !== null && typeof result === 'object' && Object.hasOwn(result, key), `Referencia rota: ${value}`);
    result = result[key];
  }
  return result;
}
function walk(value, fn) {
  if (Array.isArray(value)) value.forEach((item) => walk(item, fn));
  else if (value && typeof value === 'object') {
    fn(value);
    Object.values(value).forEach((item) => walk(item, fn));
  }
}
const documents = files.map((file) => {
  const doc = JSON.parse(readFileSync(resolve(root, file), 'utf8'));
  check(doc.openapi === '3.0.3', `${file}: versión inesperada`);
  check(doc.info.version === '0.1.0', `${file}: actualizar coherentemente la versión`);
  check(/propuest/i.test(doc.info.title), `${file}: marcar como propuesta`);
  check(JSON.stringify(doc.components.schemas.MaterialStatus.enum) === JSON.stringify(states), `${file}: estados canónicos incorrectos`);
  const ids = new Set();
  walk(doc, (node) => {
    if (node.$ref) pointer(doc, node.$ref);
    if (node.required && node.type === 'object') {
      node.required.forEach((name) => check(Object.hasOwn(node.properties || {}, name), `${file}: required sin propiedad ${name}`));
    }
  });
  const internal = file.includes('internal');
  const expectedSecurity = internal ? 'qualityServiceAuth' : 'bearerAuth';
  let count = 0;
  for (const [path, pathItem] of Object.entries(doc.paths)) {
    check(path.startsWith(internal ? '/internal/v1/quality' : '/api/v1/quality'), `${file}: prefijo inesperado ${path}`);
    for (const [method, op] of Object.entries(pathItem)) {
      if (!['get', 'post', 'put', 'patch', 'delete'].includes(method)) continue;
      count += 1;
      check(op.operationId && !ids.has(op.operationId), `${file}: operationId ausente o duplicado`);
      ids.add(op.operationId);
      check(op.summary && op.description, `${path}: falta descripción`);
      const parameters = (op.parameters || []).map((p) => (p.$ref ? pointer(doc, p.$ref) : p));
      const names = new Set();
      for (const p of parameters) {
        const key = `${p.in}:${p.name}`;
        check(!names.has(key), `${path}: parámetro duplicado ${key}`);
        names.add(key);
      }
      const placeholders = [...path.matchAll(/\{([^}]+)\}/g)].map((m) => m[1]);
      for (const name of placeholders) {
        check(parameters.some((p) => p.name === name && p.in === 'path' && p.required && p.schema.format === 'uuid'), `${path}: falta UUID requerido ${name}`);
      }
      for (const p of parameters.filter((p) => p.in === 'path')) check(placeholders.includes(p.name), `${path}: parámetro extra ${p.name}`);
      check(Object.keys(op.responses).some((s) => /^2\d\d$/.test(s)), `${path}: falta respuesta exitosa`);
      check(Array.isArray(op.security), `${path}: seguridad no explícita`);
      const publicSummary = !internal && op.operationId === 'getRatingSummary';
      if (publicSummary) check(op.security.length === 0, 'Resumen público requiere security=[]');
      else {
        check(op.security.length === 1 && Object.hasOwn(op.security[0], expectedSecurity), `${path}: esquema de seguridad incorrecto`);
        check(op.responses['401'] && op.responses['403'], `${path}: faltan 401/403`);
      }
      check(Array.isArray(op['x-allowed-roles']), `${path}: faltan roles`);
      for (const role of op['x-allowed-roles']) check(roles.has(role), `${path}: rol desconocido ${role}`);
      if (internal || path.includes('/moderation/')) {
        check(JSON.stringify(op['x-allowed-roles']) === JSON.stringify(['MODERATOR', 'ADMIN']), `${path}: permisos de moderación incorrectos`);
      }
      if (internal) check(op['x-required-scope'], `${path}: scope interno ausente`);
      if (!internal && ['submitModerationDecision', 'createReport', 'updateReport'].includes(op.operationId)) {
        check(parameters.some((p) => p.in === 'header' && p.name === 'Idempotency-Key' && p.required), `${path}: falta clave de idempotencia`);
        check(op.responses['409'], `${path}: falta conflicto 409`);
      }
      if (op.requestBody) {
        const schema = op.requestBody.content['application/json'].schema;
        const dto = schema.$ref ? pointer(doc, schema.$ref) : schema;
        check(dto.additionalProperties === false, `${path}: DTO abierto`);
        for (const forbidden of ['actorId', 'userId', 'role', 'verified']) {
          check(!Object.hasOwn(dto.properties, forbidden), `${path}: identidad/privilegio editable ${forbidden}`);
        }
      }
    }
  }
  check(count === (internal ? 5 : 17), `${file}: cambió el inventario de operaciones; revisar alcance y actualizar validación`);
  console.log(`OK ${file}: ${count} operaciones, referencias y seguridad declarada.`);
  return doc;
});
const publicDoc = documents[0];
const submit = publicDoc.paths['/api/v1/quality/moderation/materials/{materialId}/decisions'].post;
check(submit.responses['202'] && submit.responses['200'] && !submit.responses['201'], 'Decisiones: nueva aceptación 202 y replay terminal 200');
check(submit.responses['202'].headers.Location, 'Decisiones: falta Location');
const rating = publicDoc.components.schemas.RatingUpsertDto.properties.score;
check(rating.type === 'integer' && rating.minimum === 1 && rating.maximum === 5, 'Rating debe ser entero 1..5');
check(publicDoc.components.schemas.ErrorDto.properties.field, 'El error debe admitir field');
const sample = publicDoc.components.schemas.ModerationOperationDto.example;
check(sample.state === 'PENDING_APPLICATION' && sample.result === null && sample.failure === null, 'Ejemplo de aceptación no debe afirmar aplicación');
for (const file of ['docs/api/quality-contracts.md', 'docs/architecture/quality-publication.md', 'docs/testing/quality-contracts-acceptance.md']) {
  const absolute = resolve(root, file);
  const content = readFileSync(absolute, 'utf8');
  check(/propuesta|propuesto/i.test(content), `${file}: falta estado documental`);
  for (const match of content.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    const target = match[1];
    if (/^https?:\/\//.test(target) || target.startsWith('#')) continue;
    check(existsSync(resolve(dirname(absolute), target.split('#')[0])), `${file}: enlace local roto ${target}`);
  }
}
console.log(`Contrato documental OK (${checks} comprobaciones). No valida ejecución HTTP, permisos reales ni migraciones.`);
