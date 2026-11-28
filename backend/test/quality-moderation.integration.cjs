// Real PostgreSQL + HTTP integration. Uses disposable schemas in three explicitly supplied databases.
require('reflect-metadata');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID, generateKeyPairSync } = require('node:crypto');
const { mkdtempSync, writeFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { resolve, join } = require('node:path');
const { execFileSync } = require('node:child_process');
const { Readable } = require('node:stream');
const { sign } = require('jsonwebtoken');
const { Test } = require('@nestjs/testing');
const { ValidationPipe, Logger } = require('@nestjs/common');
const root = resolve(__dirname, '..');
const load = (service, path) =>
  require(resolve(root, service, 'dist', service === 'auth-service' ? 'src' : '', path));
const {
  PrismaClient: QualityDb,
} = require('../quality-service/node_modules/.prisma/quality-client');
const {
  PrismaClient: MaterialDb,
} = require('../material-service/node_modules/.prisma/material-client');
const { PrismaClient: AuthDb } = require('../node_modules/.prisma/auth-client');
const { serviceToken } = load('quality-service', 'infrastructure/moderation/service-assertion');
const pem = (key, type) => key.export({ type, format: 'pem' }).toString();

test(
  'Moderación: HTTP autorizado, PostgreSQL, concurrencia y recuperación',
  { timeout: 180000 },
  async (t) => {
    const savedEnv = { ...process.env },
      apps = [],
      clients = [];
    const suffix = randomUUID().replaceAll('-', '');
    const directory = mkdtempSync(join(tmpdir(), 'quality-moderation-'));
    const configs = ['QUALITY', 'MATERIAL', 'AUTH'].map((name) => {
      const raw = process.env[`MODERATION_TEST_${name}_DATABASE_URL`];
      assert.ok(raw, `Falta MODERATION_TEST_${name}_DATABASE_URL`);
      const url = new URL(raw);
      assert.ok(['postgres:', 'postgresql:'].includes(url.protocol));
      assert.equal(url.pathname, `/${name.toLowerCase()}_db`);
      const schema = 'moderation_test_' + suffix;
      url.searchParams.set('schema', schema);
      return { name, url: url.toString(), schema };
    });
    const authKeys = generateKeyPairSync('rsa', { modulusLength: 2048 }),
      serviceKeys = generateKeyPairSync('rsa', { modulusLength: 2048 });
    writeFileSync(join(directory, 'auth.pem'), pem(authKeys.privateKey, 'pkcs8'), { mode: 0o600 });
    Object.assign(process.env, {
      NODE_ENV: 'test',
      JWT_PRIVATE_KEY_PATH: join(directory, 'auth.pem'),
      JWT_ACCESS_PUBLIC_KEY: pem(authKeys.publicKey, 'spki'),
      JWT_ISSUER: 'test-auth',
      JWT_AUDIENCE: 'test-api',
      QUALITY_SERVICE_PRIVATE_KEY: pem(serviceKeys.privateKey, 'pkcs8'),
      QUALITY_SERVICE_PUBLIC_KEY: pem(serviceKeys.publicKey, 'spki'),
      QUALITY_MODERATION_ENABLED: 'true',
      QUALITY_WORKER_ENABLED: 'false',
    });
    const audits = [];
    const originalLog = Logger.prototype.log;
    Logger.prototype.log = function (message, ...args) {
      if (this.context === 'ModerationAccessAudit') audits.push(message);
    };
    async function start(module, setup) {
      const app = module.createNestApplication({ logger: false });
      if (setup) setup(app);
      await app.listen(0, '127.0.0.1');
      apps.push(app);
      return app;
    }
    async function http(base, path, token, method = 'GET', body, headers = {}) {
      const response = await fetch(base + path, {
        method,
        headers: {
          ...(token ? { Authorization: 'Bearer ' + token } : {}),
          ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
          ...headers,
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      const data = await response.json();
      return { status: response.status, body: data, headers: response.headers };
    }
    let q,
      m,
      a,
      worker,
      base,
      materialBase,
      gatewayBase,
      moderator,
      admin,
      student,
      author,
      token,
      adminToken,
      studentToken,
      materialApp,
      qualityApp;
    try {
      for (const c of configs) {
        execFileSync(
          process.execPath,
          [
            require.resolve('prisma/build/index.js', {
              paths: [resolve(root, c.name.toLowerCase() + '-service')],
            }),
            'migrate',
            'deploy',
          ],
          {
            cwd: resolve(root, c.name.toLowerCase() + '-service'),
            env: { ...process.env, DATABASE_URL: c.url },
            stdio: 'pipe',
            timeout: 60000,
          },
        );
      }
      q = new QualityDb({ datasources: { db: { url: configs[0].url } } });
      m = new MaterialDb({ datasources: { db: { url: configs[1].url } } });
      a = new AuthDb({ datasources: { db: { url: configs[2].url } } });
      clients.push(q, m, a);
      for (const [role, save] of [
        ['MODERATOR', (u) => (moderator = u)],
        ['ADMIN', (u) => (admin = u)],
        ['STUDENT', (u) => (student = u)],
        ['STUDENT', (u) => (author = u)],
      ])
        save(
          await a.user.create({
            data: {
              name: 'Integration',
              email: randomUUID() + '@uct.cl',
              passwordHash: 'unused-test-hash',
              role,
            },
          }),
        );
      const authModule = await Test.createTestingModule({
        controllers: [
          load('auth-service', 'presentation/auth/quality-identity.controller')
            .QualityIdentityController,
        ],
        providers: [
          load('auth-service', 'infrastructure/security/access-token.service').AccessTokenService,
          {
            provide: load('auth-service', 'infrastructure/prisma/prisma.service').PrismaService,
            useValue: a,
          },
        ],
      }).compile();
      const authApp = await start(authModule, (app) => {
        app.setGlobalPrefix('api/v1', { exclude: ['internal/v1/quality/identity'] });
        app.useGlobalPipes(
          new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
        );
      });
      process.env.AUTH_INTERNAL_URL = await authApp.getUrl();
      const tokens = authApp.get(
        load('auth-service', 'infrastructure/security/access-token.service').AccessTokenService,
      );
      token = tokens.issue(moderator);
      adminToken = tokens.issue(admin);
      studentToken = tokens.issue(student);
      const fileBytes = Buffer.from('%PDF-1.7\nIntegration fixture');
      const objects = new Map([['fixture', fileBytes]]);
      const storage = {
        async get(key) {
          if (!objects.has(key)) throw Error('missing');
          return Readable.from([objects.get(key)]);
        },
        async save(bytes) {
          const key = randomUUID();
          objects.set(key, bytes);
          return { storageKey: key };
        },
        async remove(key) {
          objects.delete(key);
        },
      };
      const { MaterialsService } = load(
        'material-service',
        'application/services/materials.service',
      );
      const { QualityModerationService } = load(
        'material-service',
        'application/services/quality-moderation.service',
      );
      const matModule = await Test.createTestingModule({
        controllers: [
          load('material-service', 'presentation/materials/quality-internal.controller')
            .QualityInternalController,
          load('material-service', 'presentation/materials/materials.controller')
            .MaterialsController,
        ],
        providers: [
          MaterialsService,
          QualityModerationService,
          load('material-service', 'infrastructure/moderation/quality-service.guard')
            .QualityServiceGuard,
          {
            provide: load('material-service', 'infrastructure/prisma/prisma.service').PrismaService,
            useValue: m,
          },
          {
            provide: load('material-service', 'application/ports/object-storage.port')
              .ObjectStorage,
            useValue: storage,
          },
        ],
      }).compile();
      materialApp = await start(matModule, load('material-service', 'setup-app').setupApp);
      materialBase = await materialApp.getUrl();
      process.env.MATERIAL_INTERNAL_URL = materialBase;
      process.env.DATABASE_URL = configs[0].url;
      const qualityModule = await Test.createTestingModule({
        imports: [load('quality-service', 'app.module').AppModule],
      })
        .overrideProvider(
          load('quality-service', 'infrastructure/prisma/prisma.service').PrismaService,
        )
        .useValue(q)
        .compile();
      qualityApp = await start(qualityModule, load('quality-service', 'setup-app').setupApp);
      base = await qualityApp.getUrl();
      worker = qualityApp.get(
        load('quality-service', 'application/moderation-worker').ModerationWorker,
      );
      process.env.QUALITY_SERVICE_URL = base;
      process.env.MATERIAL_SERVICE_URL = materialBase;
      const gatewayModule = await Test.createTestingModule({
        imports: [load('api-gateway', 'app.module').AppModule],
      }).compile();
      const gateway = await start(
        gatewayModule,
        load('api-gateway', 'configure-routes').configureRoutes,
      );
      gatewayBase = await gateway.getUrl();
      const type = await m.materialType.findUniqueOrThrow({ where: { name: 'DOCUMENT' } });
      async function material(uploader = author.id) {
        return m.material.create({
          data: {
            uploaderId: uploader,
            subjectId: randomUUID(),
            materialTypeId: type.id,
            title: 'Material de prueba',
            academicYear: 2026,
            versions: {
              create: {
                versionNumber: 1,
                storageKey: 'fixture',
                originalFilename: 'fixture.pdf',
                mimeType: 'application/pdf',
                fileSize: BigInt(fileBytes.length),
                checksum: 'fixture-checksum',
                createdBy: uploader,
              },
            },
          },
          include: { versions: true },
        });
      }
      const path = (id) => '/api/v1/quality/moderation/materials/' + id;
      const submit = (
        mat,
        body = { action: 'APPROVE', expectedRevision: 1 },
        key = randomUUID(),
        jwt = token,
        target = gatewayBase,
      ) => http(target, path(mat.id) + '/decisions', jwt, 'POST', body, { 'Idempotency-Key': key });
      const pending = await material();
      await t.test(
        '401 sin token, expirado, firma falsa o mock; 403 STUDENT incluso GET privado',
        async () => {
          const expired = sign({ sub: moderator.id, role: 'MODERATOR' }, authKeys.privateKey, {
            algorithm: 'RS256',
            issuer: 'test-auth',
            audience: 'test-api',
            expiresIn: -1,
          });
          const forged = sign({ sub: moderator.id, role: 'MODERATOR' }, serviceKeys.privateKey, {
            algorithm: 'RS256',
            expiresIn: 60,
          });
          const mock = sign(
            { sub: moderator.id, role: 'MODERATOR', mock: true },
            authKeys.privateKey,
            { algorithm: 'RS256', issuer: 'test-auth', audience: 'test-api', expiresIn: 60 },
          );
          for (const bad of [undefined, expired, forged, mock]) {
            const r = await http(
              gatewayBase,
              path(pending.id) + '/decisions',
              bad,
              'POST',
              { action: 'APPROVE', expectedRevision: 1 },
              { 'Idempotency-Key': randomUUID() },
            );
            assert.equal(r.status, 401);
            assert.equal(r.headers.get('www-authenticate'), 'Bearer');
          }
          assert.equal((await submit(pending, undefined, randomUUID(), studentToken)).status, 403);
          assert.equal((await http(gatewayBase, path(pending.id), studentToken)).status, 403);
          assert.equal((await http(base, path(pending.id), studentToken)).status, 403);
          assert.equal(await q.moderationOperation.count(), 0);
        },
      );
      await t.test(
        'snapshot, listado y descarga privada auditados; pendientes no públicos',
        async () => {
          const snapshot = await http(gatewayBase, path(pending.id), token);
          assert.equal(snapshot.status, 200);
          assert.equal(snapshot.body.revision, 1);
          assert.ok(!JSON.stringify(snapshot.body).includes('storageKey'));
          const list = await http(gatewayBase, '/api/v1/quality/moderation/materials', token);
          assert.equal(list.status, 200);
          assert.equal(list.body.total, 1);
          const dl = await fetch(
            gatewayBase + path(pending.id) + '/versions/' + pending.versions[0].id + '/download',
            { headers: { Authorization: 'Bearer ' + token } },
          );
          assert.equal(dl.status, 200);
          assert.equal(dl.headers.get('cache-control'), 'no-store');
          assert.match(dl.headers.get('content-disposition'), /^attachment/);
          assert.deepEqual(Buffer.from(await dl.arrayBuffer()), fileBytes);
          assert.equal((await http(materialBase, '/api/v1/materials/' + pending.id)).status, 404);
          assert.ok(
            audits.some(
              (e) =>
                e.action === 'READ_PRIVATE_MATERIAL' &&
                e.service === 'quality-service' &&
                e.actorId === moderator.id,
            ),
          );
          assert.ok(
            audits.some(
              (e) =>
                e.action === 'DOWNLOAD_PRIVATE_VERSION' &&
                e.phase === 'TRANSFER_RESULT' &&
                e.service === 'material-service',
            ),
          );
          const readAudit = audits.find(
            (e) =>
              e.action === 'READ_PRIVATE_MATERIAL' &&
              e.service === 'quality-service' &&
              e.outcome === 'SUCCESS',
          );
          assert.ok(
            audits.some(
              (e) => e.service === 'material-service' && e.requestId === readAudit.requestId,
            ),
          );
        },
      );
      let approved;
      await t.test(
        'aprobación 202, evidencia durable, APPLIED, replay terminal y publicación',
        async () => {
          const key = randomUUID();
          const accepted = await submit(pending, undefined, key);
          assert.equal(accepted.status, 202, JSON.stringify(accepted.body));
          approved = accepted.body;
          assert.equal(approved.state, 'PENDING_APPLICATION');
          assert.equal(approved.result, null);
          assert.equal(
            (await m.material.findUnique({ where: { id: pending.id } })).status,
            'PENDING_REVIEW',
          );
          assert.equal((await submit(pending, undefined, key)).body.id, approved.id);
          await worker.tick();
          const result = await http(base, accepted.headers.get('location'), token);
          assert.equal(result.body.state, 'APPLIED', JSON.stringify(result.body));
          assert.equal(result.body.result.status, 'PUBLISHED');
          assert.equal(result.body.result.revision, 2);
          const replay = await submit(pending, undefined, key);
          assert.equal(replay.status, 200);
          assert.equal(replay.body.id, approved.id);
          assert.equal(await q.review.count({ where: { operationId: approved.id } }), 1);
          assert.equal(
            await m.qualityDecisionReceipt.count({ where: { operationId: approved.id } }),
            1,
          );
          assert.equal((await http(materialBase, '/api/v1/materials/' + pending.id)).status, 200);
          assert.equal(
            (
              await submit(
                pending,
                { action: 'REJECT', expectedRevision: 1, reason: 'Otra solicitud' },
                key,
              )
            ).status,
            409,
          );
          assert.equal(
            (await submit(pending, { action: 'APPROVE', expectedRevision: 2 })).body.code,
            'INVALID_TRANSITION',
          );
        },
      );
      await t.test(
        'rechazo exige motivo; ADMIN puede rechazar; no hay visibilidad pública',
        async () => {
          const mat = await material();
          for (const body of [
            { action: 'REJECT', expectedRevision: 1 },
            { action: 'REJECT', expectedRevision: 1, reason: ' ' },
            { action: 'APPROVE', expectedRevision: 1, status: 'PUBLISHED' },
            { action: 'APPROVE', expectedRevision: '1' },
          ])
            assert.equal((await submit(mat, body)).status, 400);
          const r = await submit(
            mat,
            { action: 'REJECT', expectedRevision: 1, reason: '  Incompleto  ' },
            randomUUID(),
            adminToken,
          );
          assert.equal(r.status, 202);
          await worker.tick();
          const op = await q.moderationOperation.findUnique({ where: { id: r.body.id } });
          assert.equal(op.state, 'APPLIED');
          assert.equal(op.actorId, admin.id);
          assert.equal(op.reason, 'Incompleto');
          const review = await q.review.findUnique({ where: { operationId: op.id } });
          assert.equal(review.decision, 'REJECT');
          assert.equal(review.comment, 'Incompleto');
          assert.ok(review.createdAt);
          assert.equal((await http(materialBase, '/api/v1/materials/' + mat.id)).status, 404);
          assert.equal(
            (await fetch(materialBase + '/api/v1/materials/' + mat.id + '/download')).status,
            404,
          );
          assert.ok(
            !(await http(materialBase, '/api/v1/materials')).body.items.some(
              (x) => x.id === mat.id,
            ),
          );
        },
      );
      await t.test('autorrevisión prohibida incluso para ADMIN', async () => {
        for (const [actor, jwt] of [
          [moderator, token],
          [admin, adminToken],
        ])
          assert.equal(
            (await submit(await material(actor.id), undefined, randomUUID(), jwt)).body.code,
            'SELF_REVIEW_FORBIDDEN',
          );
      });
      await t.test(
        'aceptación concurrente con misma clave produce una operación y una evidencia',
        async () => {
          const mat = await material(),
            key = randomUUID();
          const responses = await Promise.all(
            Array.from({ length: 5 }, () => submit(mat, undefined, key)),
          );
          assert.ok(responses.every((r) => r.status === 202));
          assert.equal(new Set(responses.map((r) => r.body.id)).size, 1);
          assert.equal(await q.review.count({ where: { operationId: responses[0].body.id } }), 1);
          await Promise.all([worker.tick(), worker.tick()]);
          assert.equal((await m.material.findUnique({ where: { id: mat.id } })).revision, 2);
        },
      );
      await t.test('decisiones distintas concurrentes: solo una aplica', async () => {
        const mat = await material();
        const responses = await Promise.all([
          submit(mat),
          submit(mat, { action: 'REJECT', expectedRevision: 1, reason: 'Rechazar' }),
        ]);
        assert.ok(responses.every((r) => r.status === 202));
        await Promise.all([worker.tick(), worker.tick()]);
        await worker.tick();
        const operations = await q.moderationOperation.findMany({ where: { materialId: mat.id } });
        assert.deepEqual(operations.map((o) => o.state).sort(), ['APPLIED', 'FAILED']);
        assert.equal((await m.material.findUnique({ where: { id: mat.id } })).revision, 2);
      });
      await t.test('rollback de aceptación no deja operación, Review ni outbox', async () => {
        const mat = await material();
        await q.$executeRawUnsafe(
          `CREATE FUNCTION "${configs[0].schema}".fail_outbox() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'test rollback'; END; $$`,
        );
        await q.$executeRawUnsafe(
          `CREATE TRIGGER fail_outbox BEFORE INSERT ON "${configs[0].schema}".moderation_outbox FOR EACH ROW EXECUTE FUNCTION "${configs[0].schema}".fail_outbox()`,
        );
        try {
          assert.equal((await submit(mat)).status, 503);
          assert.equal(await q.moderationOperation.count({ where: { materialId: mat.id } }), 0);
          assert.equal(await q.review.count({ where: { materialId: mat.id } }), 0);
        } finally {
          await q.$executeRawUnsafe(
            `DROP TRIGGER fail_outbox ON "${configs[0].schema}".moderation_outbox`,
          );
        }
      });
      await t.test(
        'pérdida de respuesta tras commit: reentrega recupera recibo sin duplicar',
        async () => {
          const mat = await material();
          const r = await submit(mat);
          const client = qualityApp.get(
            load('quality-service', 'infrastructure/moderation/material-client').MaterialClient,
          );
          const original = client.apply.bind(client);
          let lose = true;
          client.apply = async (...args) => {
            const receipt = await original(...args);
            if (lose) {
              lose = false;
              throw Error('simulated transport loss after commit');
            }
            return receipt;
          };
          try {
            await worker.tick();
            assert.equal(
              (await q.moderationOperation.findUnique({ where: { id: r.body.id } })).state,
              'PENDING_APPLICATION',
            );
            assert.equal((await m.material.findUnique({ where: { id: mat.id } })).revision, 2);
            await q.moderationOutbox.update({
              where: { operationId: r.body.id },
              data: { nextAttemptAt: new Date(0) },
            });
            await worker.tick();
            assert.equal(
              (await q.moderationOperation.findUnique({ where: { id: r.body.id } })).state,
              'APPLIED',
            );
            assert.equal((await m.material.findUnique({ where: { id: mat.id } })).revision, 2);
          } finally {
            client.apply = original;
          }
        },
      );
      await t.test('permisos actuales: cuenta inactiva, rol perdido y token revocado', async () => {
        const mat = await material();
        const accepted = await submit(mat);
        await a.user.update({ where: { id: moderator.id }, data: { active: false } });
        assert.equal((await http(base, path(mat.id), token)).status, 403);
        await a.user.update({
          where: { id: moderator.id },
          data: { active: true, role: 'STUDENT' },
        });
        assert.equal((await submit(await material())).status, 403);
        // Already accepted operations keep their original authorization.
        await worker.tick();
        assert.equal(
          (await q.moderationOperation.findUnique({ where: { id: accepted.body.id } })).state,
          'APPLIED',
        );
        await a.user.update({
          where: { id: moderator.id },
          data: { role: 'MODERATOR', tokenVersion: { increment: 1 } },
        });
        assert.equal((await http(base, path(mat.id), token)).status, 401);
        moderator = await a.user.findUnique({ where: { id: moderator.id } });
        token = tokens.issue(moderator);
        assert.equal((await http(base, path(mat.id), token)).status, 200);
      });
      await t.test(
        'nueva versión oculta el agregado y provoca conflicto de revisión en decisión pendiente',
        async () => {
          const mat = await material();
          const accepted = await submit(mat);
          const { CreateMaterialVersion } = load(
            'material-service',
            'application/use-cases/create-material-version',
          );
          await new CreateMaterialVersion(m, storage).execute(
            mat.id,
            { id: author.id, universityId: null },
            { buffer: Buffer.from('new'), mimetype: 'application/pdf', originalname: 'new.pdf' },
          );
          await worker.tick();
          assert.equal(
            (await q.moderationOperation.findUnique({ where: { id: accepted.body.id } })).state,
            'FAILED',
          );
          await new CreateMaterialVersion(m, storage).execute(
            pending.id,
            { id: author.id, universityId: null },
            { buffer: Buffer.from('new'), mimetype: 'application/pdf', originalname: 'new.pdf' },
          );
          assert.equal((await http(materialBase, '/api/v1/materials/' + pending.id)).status, 404);
        },
      );
      await t.test(
        'rutas internas no se exponen en Gateway y rechazan JWT de usuario',
        async () => {
          const resource = '/internal/v1/quality/materials/' + pending.id;
          assert.equal((await http(materialBase, resource, token)).status, 401);
          assert.equal((await http(gatewayBase, resource, token)).status, 404);
          const assertion = serviceToken(
            process.env.QUALITY_SERVICE_PRIVATE_KEY,
            'material-service',
            'material:review:read',
            resource,
            { id: moderator.id, role: 'MODERATOR', authorizedAt: new Date().toISOString() },
          );
          assert.equal((await http(materialBase, resource, assertion)).status, 200);
          assert.equal((await http(materialBase, '/api/v1' + resource, assertion)).status, 404);
        },
      );
      await t.test(
        'Material serializa dos entregas del mismo operationId y rechaza payload diferente',
        async () => {
          const mat = await material(),
            id = randomUUID(),
            body = { action: 'APPROVE', expectedRevision: 1 };
          const actor = {
            id: moderator.id,
            role: 'MODERATOR',
            authorizedAt: new Date().toISOString(),
          };
          const resource = '/internal/v1/quality/materials/' + mat.id + '/decisions/' + id;
          const send = (payload) =>
            http(
              materialBase,
              resource,
              serviceToken(
                process.env.QUALITY_SERVICE_PRIVATE_KEY,
                'material-service',
                'material:quality:apply',
                resource,
                actor,
                payload,
                id,
              ),
              'PUT',
              payload,
            );
          const results = await Promise.all([send(body), send(body)]);
          assert.ok(results.every((r) => r.status === 200));
          assert.deepEqual(results[0].body, results[1].body);
          assert.equal((await m.material.findUnique({ where: { id: mat.id } })).revision, 2);
          assert.equal(
            (await send({ action: 'REJECT', expectedRevision: 1, reason: 'Otro contenido' }))
              .status,
            409,
          );
          const receiptPath = '/internal/v1/quality/decisions/' + id;
          assert.deepEqual(
            (
              await http(
                materialBase,
                receiptPath,
                serviceToken(
                  process.env.QUALITY_SERVICE_PRIVATE_KEY,
                  'material-service',
                  'material:quality:apply',
                  receiptPath,
                  actor,
                  null,
                  id,
                ),
              )
            ).body,
            results[0].body,
          );
        },
      );
      await t.test(
        'caída de Material tras aceptar y concesión vencida se recuperan desde outbox',
        async () => {
          const mat = await material();
          const r = await submit(mat);
          const origin = process.env.MATERIAL_INTERNAL_URL;
          process.env.MATERIAL_INTERNAL_URL = 'http://127.0.0.1:1';
          try {
            await worker.tick();
          } finally {
            process.env.MATERIAL_INTERNAL_URL = origin;
          }
          assert.equal(
            (await q.moderationOperation.findUnique({ where: { id: r.body.id } })).state,
            'PENDING_APPLICATION',
          );
          await q.moderationOutbox.update({
            where: { operationId: r.body.id },
            data: { nextAttemptAt: new Date(0), leaseToken: randomUUID(), leaseUntil: new Date(0) },
          });
          const restarted = new (load(
            'quality-service',
            'application/moderation-worker',
          ).ModerationWorker)(
            q,
            qualityApp.get(
              load('quality-service', 'infrastructure/moderation/material-client').MaterialClient,
            ),
          );
          await restarted.tick();
          assert.equal(
            (await q.moderationOperation.findUnique({ where: { id: r.body.id } })).state,
            'APPLIED',
          );
        },
      );
      await t.test(
        'recibo inconsistente y credencial interna inválida no se convierten en FAILED',
        async () => {
          const mat = await material();
          const r = await submit(mat);
          const originalFetch = global.fetch;
          global.fetch = async (url, options) => {
            const response = await originalFetch(url, options);
            if (
              options?.method === 'PUT' &&
              String(url).includes('/internal/v1/quality/materials/')
            ) {
              const body = await response.json();
              body.result.revision = 999;
              return new Response(JSON.stringify(body), {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
              });
            }
            return response;
          };
          try {
            await worker.tick();
          } finally {
            global.fetch = originalFetch;
          }
          assert.equal(
            (await q.moderationOperation.findUnique({ where: { id: r.body.id } })).state,
            'PENDING_APPLICATION',
          );
          await q.moderationOutbox.update({
            where: { operationId: r.body.id },
            data: { nextAttemptAt: new Date(0) },
          });
          await worker.tick();
          assert.equal(
            (await q.moderationOperation.findUnique({ where: { id: r.body.id } })).state,
            'APPLIED',
          );
          const key = process.env.QUALITY_SERVICE_PUBLIC_KEY;
          process.env.QUALITY_SERVICE_PUBLIC_KEY = pem(authKeys.publicKey, 'spki');
          try {
            assert.equal((await http(base, path(mat.id), token)).status, 503);
          } finally {
            process.env.QUALITY_SERVICE_PUBLIC_KEY = key;
          }
        },
      );
      await t.test(
        'fallo de Auth no concede acceso; auditoría no incluye tokens ni storageKey',
        async () => {
          const old = process.env.AUTH_INTERNAL_URL;
          process.env.AUTH_INTERNAL_URL = 'http://127.0.0.1:1';
          try {
            assert.equal((await http(base, path(pending.id), token)).status, 503);
          } finally {
            process.env.AUTH_INTERNAL_URL = old;
          }
          const serialized = JSON.stringify(audits);
          assert.ok(!serialized.includes(token));
          assert.ok(!serialized.includes('storageKey'));
          assert.ok(audits.some((e) => e.outcome === 'DENIED'));
        },
      );
    } finally {
      Logger.prototype.log = originalLog;
      for (const app of apps.reverse()) await app.close();
      for (let i = 0; i < clients.length; i++) {
        try {
          await clients[i].$executeRawUnsafe(
            `DROP SCHEMA IF EXISTS "${configs[i].schema}" CASCADE`,
          );
        } finally {
          await clients[i].$disconnect();
        }
      }
      rmSync(directory, { recursive: true, force: true });
      for (const k of Object.keys(process.env)) if (!(k in savedEnv)) delete process.env[k];
      Object.assign(process.env, savedEnv);
    }
  },
);
