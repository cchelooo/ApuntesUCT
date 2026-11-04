/* Stack desechable para la comprobación nativa de Mobile.
 * Prerrequisitos: Docker activo, backend con npm ci y npm run build.
 * Crea solo recursos qa278-*; SIGINT/SIGTERM retiran esos recursos.
 * No inicia la Web ni modifica bases compartidas. El login sigue siendo mock.
 */
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const net = require("node:net");
const assert = require("node:assert/strict");
const { spawn, execFileSync } = require("node:child_process");
const { randomUUID, createHash } = require("node:crypto");
const root = path.resolve(__dirname, "../..");
const backend = path.join(root, "backend");

const { PrismaClient: Catalog } = require(
  path.join(backend, "node_modules/.prisma/catalog-client"),
);
const { PrismaClient: Material } = require(
  path.join(backend, "material-service/node_modules/.prisma/material-client"),
);
const { Client } = require(path.join(backend, "node_modules/minio"));
const out = path.resolve(
  process.env.QA_OUTPUT_DIR || fs.mkdtempSync(path.join(os.tmpdir(), "qa278-")),
);
fs.mkdirSync(out, { recursive: true });
const runId = `qa278-${randomUUID().slice(0, 8)}`;
const containers = [],
  children = [],
  clients = [];
const report = {
  startedAt: new Date().toISOString(),
  commit: execFileSync("git", ["rev-parse", "HEAD"], {
    cwd: root,
    encoding: "utf8",
  }).trim(),
  platform: `${os.platform()} ${os.release()}`,
  node: process.version,
  health: {},
  images: {},
  scriptSha256: createHash("sha256")
    .update(fs.readFileSync(__filename))
    .digest("hex"),
  cleanup: [],
};
let stopRequested = false;
const stopSignal = new Promise((resolve) => {
  for (const signal of ["SIGINT", "SIGTERM"]) {
    process.once(signal, () => {
      stopRequested = true;
      resolve();
    });
  }
});
const pause = (ms) => new Promise((r) => setTimeout(r, ms));
function docker(...args) {
  return execFileSync("docker", args, {
    encoding: "utf8",
    timeout: 120000,
  }).trim();
}
async function freePort() {
  const server = net.createServer();
  await new Promise((r, j) => {
    server.once("error", j);
    server.listen(0, "127.0.0.1", r);
  });
  const port = server.address().port;
  await new Promise((r) => server.close(r));
  return port;
}
async function ready(url) {
  for (let n = 0; n < 60; n++) {
    if (stopRequested) throw new Error("Preparacion interrumpida");
    try {
      const r = await fetch(url, { signal: AbortSignal.timeout(1000) });
      if (r.ok) return r.status;
    } catch {}
    await pause(500);
  }
  throw new Error(`Health no disponible: ${url}`);
}
function start(name, command, args, cwd, env) {
  const fd = fs.openSync(path.join(out, `${name}.log`), "w");
  const child = spawn(command, args, {
    cwd,
    env: { ...process.env, ...env },
    stdio: ["ignore", fd, fd],
  });
  fs.closeSync(fd);
  children.push(child);
  child.on("error", (e) => console.error(name, e.message));
  return child;
}
async function main() {
  console.log(`Evidencia: ${out}`);
  const pgName = `${runId}-postgres`,
    minioName = `${runId}-minio`;
  for (const [name, image, args] of [
    [
      pgName,
      "postgres:17-alpine",
      [
        "--publish",
        "127.0.0.1::5432",
        "--env",
        "POSTGRES_USER=qa",
        "--env",
        "POSTGRES_PASSWORD=qa-disposable",
        "--env",
        "POSTGRES_DB=qa",
      ],
    ],
    [
      minioName,
      process.env.QA_MINIO_IMAGE || "apuntesuct/kubero-minio:local",
      [
        "--publish",
        "127.0.0.1::9000",
        "--env",
        "MINIO_ROOT_USER=qa-minio",
        "--env",
        "MINIO_ROOT_PASSWORD=qa-disposable-minio",
      ],
    ],
  ]) {
    docker(
      "run",
      "--detach",
      "--name",
      name,
      ...args,
      image,
      ...(name === minioName ? ["server", "/data"] : []),
    );
    containers.push(name);
    report.images[name] = docker("inspect", "--format", "{{.Image}}", name);
  }
  const pgPort = docker("port", pgName, "5432/tcp").split(":").pop();
  const minioPort = Number(
    docker("port", minioName, "9000/tcp").split(":").pop(),
  );
  for (let n = 0; n < 30; n++) {
    try {
      docker("exec", pgName, "pg_isready", "-U", "qa", "-d", "qa");
      break;
    } catch {
      await pause(500);
    }
  }
  const db = (schema) =>
    `postgresql://qa:qa-disposable@127.0.0.1:${pgPort}/qa?schema=${schema}`;
  for (const service of ["auth", "catalog", "material"]) {
    const migrationFd = fs.openSync(
      path.join(out, `migrate-${service}.log`),
      "w",
    );
    try {
      execFileSync(
        "npm",
        ["run", "prisma:deploy", `--workspace=${service}-service`],
        {
          cwd: backend,
          env: { ...process.env, DATABASE_URL: db(service) },
          stdio: ["ignore", migrationFd, "pipe"],
          timeout: 60000,
        },
      );
    } finally {
      fs.closeSync(migrationFd);
    }
  }
  const storage = new Client({
    endPoint: "127.0.0.1",
    port: minioPort,
    useSSL: false,
    accessKey: "qa-minio",
    secretKey: "qa-disposable-minio",
  });
  for (let n = 0; n < 30; n++) {
    try {
      await storage.makeBucket("qa-materials");
      break;
    } catch (e) {
      if (n === 29) throw e;
      await pause(500);
    }
  }
  const catalog = new Catalog({ datasources: { db: { url: db("catalog") } } });
  const material = new Material({
    datasources: { db: { url: db("material") } },
  });
  clients.push(catalog, material);
  const university = await catalog.university.create({
    data: { name: "Universidad QA278", code: runId },
  });
  const career = await catalog.career.create({
    data: { name: "Carrera QA278", code: runId, universityId: university.id },
  });
  const subject = await catalog.subject.create({
    data: { name: "Asignatura QA278", code: runId, careerId: career.id },
  });
  const uploader = randomUUID();
  const ports = {};
  for (const name of ["gateway", "auth", "catalog", "material", "search"])
    ports[name] = await freePort();
  const origin = (name) => `http://127.0.0.1:${ports[name]}`;
  const gateway = `${origin("gateway")}/api/v1`,
    androidGateway = gateway.replace("127.0.0.1", "10.0.2.2");
  report.urls = { gateway, androidGateway };
  report.fixture = {
    universityId: university.id,
    careerId: career.id,
    subjectId: subject.id,
  };
  const common = { NODE_ENV: "development" };
  for (const service of ["auth", "catalog", "material", "search", "gateway"]) {
    const folder = service === "gateway" ? "api-gateway" : `${service}-service`;
    const entry = fs.existsSync(path.join(backend, folder, "dist/main.js"))
      ? "dist/main.js"
      : "dist/src/main.js";
    let env = {
      ...common,
      PORT: String(ports[service]),
      DATABASE_URL: db(service),
    };
    if (service === "material")
      Object.assign(env, {
        CATALOG_SERVICE_URL: `${origin("catalog")}/api/v1`,
        MATERIAL_LOCAL_AUTHOR_ENABLED: "true",
        MATERIAL_LOCAL_UPLOADER_ID: uploader,
        MATERIAL_LOCAL_UNIVERSITY_ID: university.id,
        MINIO_ENDPOINT: "127.0.0.1",
        MINIO_PORT: String(minioPort),
        MINIO_USE_SSL: "false",
        MINIO_BUCKET: "qa-materials",
        MINIO_ACCESS_KEY: "qa-minio",
        MINIO_SECRET_KEY: "qa-disposable-minio",
      });
    if (["search", "gateway"].includes(service))
      Object.assign(env, {
        AUTH_SERVICE_URL: origin("auth"),
        CATALOG_SERVICE_URL: origin("catalog"),
        MATERIAL_SERVICE_URL: origin("material"),
        SEARCH_SERVICE_URL: origin("search"),
      });
    start(service, process.execPath, [entry], path.join(backend, folder), env);
    report.health[service] = await ready(
      `${origin(service)}${service === "catalog" ? "/health" : "/api/v1/health"}`,
    );
  }

  const title = "Integracion278";
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>",
    "<< /Length 0 >>\nstream\n\nendstream",
  ];
  let pdfText = "%PDF-1.4\n";
  const offsets = [0];
  for (let i = 0; i < objects.length; i++) {
    offsets.push(Buffer.byteLength(pdfText));
    pdfText += `${i + 1} 0 obj\n${objects[i]}\nendobj\n`;
  }
  const xref = Buffer.byteLength(pdfText);
  pdfText += `xref\n0 5\n0000000000 65535 f \n${offsets
    .slice(1)
    .map((x) => String(x).padStart(10, "0") + " 00000 n \n")
    .join("")}trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  const pdf = Buffer.from(pdfText);
  fs.writeFileSync(path.join(out, "fixture.pdf"), pdf);
  const form = new FormData();
  for (const [key, value] of Object.entries({
    title,
    description: "PDF sintetico para smoke Mobile",
    year: "2026",
    type: "DOCUMENT",
    subjectId: subject.id,
    careerId: career.id,
  }))
    form.set(key, value);
  form.set("file", new Blob([pdf], { type: "application/pdf" }), "Guía278.pdf");
  const response = await fetch(`${gateway}/materials`, {
    method: "POST",
    body: form,
  });
  const body = await response.json();
  assert.equal(response.status, 201, JSON.stringify(body));
  const materialId = body.data.id;
  assert.equal(body.data.status, "PENDING_REVIEW");
  await material.material.update({
    where: { id: materialId },
    data: { status: "PUBLISHED" },
  });
  const download = await fetch(`${gateway}/materials/${materialId}/download`);
  assert.equal(download.status, 200);
  assert.deepEqual(Buffer.from(await download.arrayBuffer()), pdf);
  Object.assign(report.fixture, {
    materialId,
    title,
    subjectName: subject.name,
    publication:
      "Actualizacion directa solo en base desechable; no valida moderacion",
    downloadSha256: createHash("sha256").update(pdf).digest("hex"),
  });
  report.result = "READY";
  fs.writeFileSync(
    path.join(out, "fixture.json"),
    JSON.stringify(report, null, 2) + "\n",
  );
  console.log(
    JSON.stringify(
      {
        gateway,
        androidGateway: gateway.replace("127.0.0.1", "10.0.2.2"),
        ...report.fixture,
      },
      null,
      2,
    ),
  );
  await stopSignal;
}
main()
  .catch((e) => {
    report.result = "FAIL";
    report.error = e.message;
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    for (const client of clients) await client.$disconnect().catch(() => {});
    for (const child of children) {
      if (child.exitCode === null) {
        child.kill("SIGTERM");
        await Promise.race([
          new Promise((resolve) => child.once("exit", resolve)),
          pause(3000),
        ]);
        if (child.exitCode === null) child.kill("SIGKILL");
      }
    }
    for (const name of containers) {
      try {
        docker("rm", "--force", "--volumes", name);
        report.cleanup.push({ name, removed: true });
      } catch {
        process.exitCode = 1;
        report.cleanup.push({ name, removed: false });
      }
    }
    report.finishedAt = new Date().toISOString();
    fs.writeFileSync(
      path.join(out, "report.json"),
      JSON.stringify(report, null, 2) + "\n",
    );
  });
