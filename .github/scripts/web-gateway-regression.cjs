/* #268: navegador y servicios reales; solo crea/elimina contenedores propios.
 * Prerrequisitos: build backend, dependencias web, Docker y Playwright/Chromium.
 * QA_PLAYWRIGHT_MODULE permite usar Playwright instalado fuera del repositorio.
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
const { chromium } = require(process.env.QA_PLAYWRIGHT_MODULE || "playwright");
const { PrismaClient: Catalog } = require(
  path.join(backend, "node_modules/.prisma/catalog-client"),
);
const { PrismaClient: Material } = require(
  path.join(backend, "material-service/node_modules/.prisma/material-client"),
);
const { Client } = require(path.join(backend, "node_modules/minio"));
const out = path.resolve(
  process.env.QA_OUTPUT_DIR || fs.mkdtempSync(path.join(os.tmpdir(), "qa268-")),
);
fs.mkdirSync(out, { recursive: true });
const runId = `qa268-${randomUUID().slice(0, 8)}`;
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
  flows: [],
  network: [],
  requests: [],
  failedRequests: [],
  images: {},
  scriptSha256: createHash("sha256")
    .update(fs.readFileSync(__filename))
    .digest("hex"),
  pageErrors: [],
  cleanup: [],
};
let browser, page, currentFlow;
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
async function shot(name) {
  await page.screenshot({
    path: path.join(out, `${name}.png`),
    fullPage: true,
  });
}
async function flow(name, fn) {
  currentFlow = name;
  try {
    const detail = await fn();
    await shot(name);
    report.flows.push({ name, status: "PASS", ...detail });
    console.log(`PASS ${name}`);
  } catch (e) {
    report.flows.push({ name, status: "FAIL", error: e.message });
    await shot(`${name}-fallo`).catch(() => {});
    throw e;
  }
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
      process.env.QA_MINIO_IMAGE || "apuntesuct/pr-test-minio:local",
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
    data: { name: "Universidad QA268", code: runId },
  });
  const career = await catalog.career.create({
    data: { name: "Carrera QA268", code: runId, universityId: university.id },
  });
  const subject = await catalog.subject.create({
    data: { name: "Asignatura QA268", code: runId, careerId: career.id },
  });
  const uploader = randomUUID();
  const ports = {};
  for (const name of [
    "gateway",
    "auth",
    "catalog",
    "material",
    "search",
    "web",
  ])
    ports[name] = await freePort();
  const origin = (name) => `http://127.0.0.1:${ports[name]}`;
  const gateway = `${origin("gateway")}/api/v1`,
    web = origin("web");
  report.urls = { web, gateway };
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
  start(
    "web",
    process.execPath,
    [
      "node_modules/vite/bin/vite.js",
      "--host",
      "127.0.0.1",
      "--port",
      String(ports.web),
      "--strictPort",
    ],
    path.join(root, "web"),
    { VITE_API_URL: gateway },
  );
  await ready(web);
  browser = await chromium.launch({ headless: true });
  report.browser = browser.version();
  page = await browser.newPage({
    viewport: { width: 1440, height: 1000 },
    acceptDownloads: true,
  });
  page.setDefaultTimeout(15000);
  page.on("pageerror", (e) => report.pageErrors.push(e.message));
  page.on("request", (r) => {
    if (["fetch", "xhr"].includes(r.resourceType()))
      report.requests.push({
        flow: currentFlow,
        method: r.method(),
        url: r.url(),
      });
  });
  page.on("requestfailed", (r) => {
    if (["fetch", "xhr"].includes(r.resourceType()))
      report.failedRequests.push({
        url: r.url(),
        error: r.failure()?.errorText,
      });
  });
  page.on("response", (r) => {
    if (["fetch", "xhr"].includes(r.request().resourceType()))
      report.network.push({
        flow: currentFlow,
        method: r.request().method(),
        url: r.url(),
        status: r.status(),
      });
  });
  const apiResponse = (suffix, method = "GET") =>
    page.waitForResponse(
      (r) =>
        r.url().startsWith(`${gateway}${suffix}`) &&
        r.request().method() === method,
    );
  await flow("catalogo", async () => {
    const res = apiResponse("/catalog/filter");
    await page.goto(`${web}/catalog`);
    assert.equal((await res).status(), 200);
    await page.getByText("Asignatura QA268", { exact: true }).first().waitFor();
    return { http: 200 };
  });
  await flow("login", async () => {
    await page.goto(`${web}/login`);
    await page.getByLabel("Correo electrónico").fill("qa268@example.test");
    await page.getByLabel("Contraseña", { exact: true }).fill("qa-disposable");
    const res = apiResponse("/auth/login", "POST");
    await page.getByRole("button", { name: "Ingresar", exact: true }).click();
    const r = await res;
    assert.equal(r.status(), 200);
    const body = await r.json();
    assert.equal(
      JSON.parse(Buffer.from(body.accessToken.split(".")[1], "base64url")).mock,
      true,
    );
    await page
      .getByText("Inicio de sesión exitoso.", { exact: true })
      .waitFor();
    assert.equal(
      await page.evaluate(() => localStorage.length + sessionStorage.length),
      0,
    );
    return { http: 200, mock: true, sessionPersisted: false };
  });
  const title = `Regresion268 ${runId}`;
  report.fixture.title = title;
  // PDF mínimo válido, generado localmente, sin datos personales.
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
  let materialId;
  await flow("subida", async () => {
    await page.goto(`${web}/materials/upload`);
    await page.getByLabel("Título", { exact: true }).fill(title);
    await page
      .getByLabel(/Descripción/)
      .fill("Documento sintético para validar integración Web Gateway.");
    await page.getByLabel("Año", { exact: true }).fill("2026");
    await page
      .getByLabel("Universidad", { exact: true })
      .selectOption(university.id);
    await page.getByLabel("Carrera", { exact: true }).selectOption(career.id);
    await page
      .getByLabel("Asignatura", { exact: true })
      .selectOption(subject.id);
    await page
      .getByLabel("Selecciona tu archivo", { exact: true })
      .setInputFiles({
        name: "regresion268.pdf",
        mimeType: "application/pdf",
        buffer: pdf,
      });
    await page
      .getByRole("button", { name: "Revisar material", exact: true })
      .click();
    const res = apiResponse("/materials", "POST");
    await page
      .getByRole("button", { name: "Subir material", exact: true })
      .click();
    const r = await res;
    const body = await r.json();
    assert.equal(r.status(), 201, JSON.stringify(body));
    materialId = body.data.id;
    report.fixture.materialId = materialId;
    assert.equal(body.data.status, "PENDING_REVIEW");
    await page
      .getByText("¡Material subido exitosamente!", { exact: true })
      .waitFor();
    const version = await material.materialVersion.findFirstOrThrow({
      where: { materialId },
    });
    assert.equal(version.versionNumber, 1);
    await storage.statObject("qa-materials", version.storageKey);
    return {
      http: 201,
      materialId,
      initialStatus: body.data.status,
      version: 1,
      objectExists: true,
    };
  });
  // Preparación explícita de fixture: no hay moderación implementada.
  await material.material.update({
    where: { id: materialId },
    data: { status: "PUBLISHED" },
  });
  report.fixture.publication =
    "Actualización directa solo en la base desechable; moderación fuera de alcance.";
  await flow("listado", async () => {
    const res = apiResponse("/materials?");
    await page.goto(`${web}/library`);
    const r = await res;
    assert.equal(r.status(), 200);
    assert.ok((await r.json()).items.some((x) => x.id === materialId));
    await page.getByText(title, { exact: true }).first().waitFor();
    return { http: 200, materialId };
  });
  await flow("detalle", async () => {
    const res = apiResponse(`/materials/${materialId}`);
    await page.goto(`${web}/material/${materialId}`);
    const r = await res;
    assert.equal(r.status(), 200);
    assert.equal((await r.json()).id, materialId);
    await page.getByRole("heading", { name: title, exact: true }).waitFor();
    return { http: 200, materialId };
  });
  await flow("descarga", async () => {
    const res = apiResponse(`/materials/${materialId}/download`);
    const pending = page.waitForEvent("download");
    await page.getByRole("button", { name: /Descargar material/ }).click();
    const download = await pending;
    const r = await res;
    assert.equal(r.status(), 200);
    const disposition = r.headers()["content-disposition"];
    assert.ok(disposition);
    await download.saveAs(path.join(out, "descarga.pdf"));
    const saved = fs.readFileSync(path.join(out, "descarga.pdf"));
    assert.deepEqual(saved, pdf);
    return {
      http: 200,
      filename: download.suggestedFilename(),
      contentDisposition: disposition,
      bytes: saved.length,
      sha256: createHash("sha256").update(saved).digest("hex"),
    };
  });
  await flow("busqueda", async () => {
    await page.goto(`${web}/search`);
    await page.getByLabel("Buscar materiales", { exact: true }).fill(runId);
    const res = apiResponse("/search?");
    await page.getByRole("button", { name: "Buscar", exact: true }).click();
    const r = await res;
    assert.equal(r.status(), 200);
    assert.ok((await r.json()).results.some((x) => x.id === materialId));
    await page.getByText(title, { exact: true }).first().waitFor();
    return { http: 200, materialId };
  });
  assert.equal(report.pageErrors.length, 0);
  // React StrictMode cancela consultas del primer montaje en desarrollo.
  // Solo admitir cancelaciones cuando la misma URL terminó después con éxito;
  // una conexión rechazada, un error HTTP o una consulta sin respuesta falla.
  assert.ok(
    report.failedRequests.every(
      (r) =>
        r.error === "net::ERR_ABORTED" &&
        report.network.some(
          (completed) =>
            completed.url === r.url &&
            completed.status >= 200 &&
            completed.status < 300,
        ),
    ),
    "Peticiones fallidas sin recuperación",
  );
  assert.ok(report.requests.length > 0);
  assert.ok(
    report.requests.every((r) => r.url.startsWith(gateway + "/")),
    "Todas las llamadas API deben ir por Gateway",
  );
  report.result = "PASS";
}
main()
  .catch((e) => {
    report.result = "FAIL";
    report.error = e.stack;
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await browser?.close().catch(() => {});
    for (const client of clients) await client.$disconnect().catch(() => {});
    for (const child of children) {
      if (child.exitCode === null) {
        child.kill("SIGTERM");
        await Promise.race([
          new Promise((r) => child.once("exit", r)),
          pause(3000),
        ]);
        if (child.exitCode === null) child.kill("SIGKILL");
      }
    }
    for (const name of containers) {
      try {
        docker("rm", "--force", "--volumes", name);
        report.cleanup.push({ container: name, removed: true });
      } catch (e) {
        report.cleanup.push({ container: name, removed: false });
        report.result = "FAIL";
        process.exitCode = 1;
      }
    }
    report.finishedAt = new Date().toISOString();
    fs.writeFileSync(
      path.join(out, "report.json"),
      JSON.stringify(report, null, 2) + "\n",
    );
    console.log(`${report.result}: ${path.join(out, "report.json")}`);
  });
