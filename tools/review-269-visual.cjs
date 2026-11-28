// Ejecutar con Playwright disponible; instrucciones en docs/testing/revision-visual-269.md.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || "playwright");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const out = process.env.VISUAL_OUTPUT || "/tmp/apuntes-269-visual";
const origin = process.env.WEB_URL || "http://127.0.0.1:5174";
fs.mkdirSync(out, { recursive: true });
const subject = {
  id: "s1",
  careerId: "c1",
  name: "Programación y estructuras de datos",
  code: "INF101",
  active: true,
  semester: 2,
  notesCount: 4,
  career: {
    id: "c1",
    name: "Ingeniería Civil Informática",
    code: "ICI",
    university: {
      id: "u1",
      name: "Universidad Católica de Temuco",
      code: "UCT",
    },
  },
};
const version = {
  id: "v1",
  versionNumber: 2,
  originalFilename: "Guía-estructuras.pdf",
  mimeType: "application/pdf",
  fileSize: "204800",
  createdAt: "2026-11-01T12:00:00Z",
};
const material = {
  id: "m1",
  title: "Guía de estructuras de datos y algoritmos",
  description: "Material de apoyo para preparar la evaluación.",
  academicYear: 2026,
  materialType: "DOCUMENT",
  subjectId: "s1",
  professorId: "p1",
  currentVersion: version,
  versions: [version, { ...version, id: "v0", versionNumber: 1 }],
};
const report =
  process.env.RESUME && fs.existsSync(path.join(out, "report.json"))
    ? JSON.parse(fs.readFileSync(path.join(out, "report.json"), "utf8"))
    : { scenarios: [], interactions: {} };
async function api(route, state) {
  const u = new URL(route.request().url());
  let body = [];
  const isContent = /\/(filter|search|materials|m1)$/.test(u.pathname);
  if (state === "loading" && isContent) return;
  if (state === "error" && isContent)
    return route.fulfill({
      status: 502,
      json: {
        message: "Technical upstream failure: database connection refused",
      },
    });
  if (state === "missing" && u.pathname.endsWith("/m1"))
    return route.fulfill({
      status: 404,
      json: { message: "Internal identifier missing" },
    });
  if (u.pathname.endsWith("/filter") || u.pathname.endsWith("/subjects"))
    body = state === "empty" && u.pathname.endsWith("/filter") ? [] : [subject];
  else if (u.pathname.endsWith("/universities"))
    body = [{ id: "u1", name: "Universidad Católica de Temuco", code: "UCT" }];
  else if (u.pathname.endsWith("/careers"))
    body = [
      {
        id: "c1",
        universityId: "u1",
        name: "Ingeniería Civil Informática",
        code: "ICI",
      },
    ];
  else if (u.pathname.endsWith("/professors"))
    body = [{ id: "p1", name: "Docente de prueba", subjectId: "s1" }];
  else if (u.pathname.endsWith("/m1"))
    body =
      state === "long"
        ? {
            ...material,
            title: "TítuloLargo".repeat(20),
            description: "DescripciónLarga".repeat(40),
            currentVersion: {
              ...version,
              originalFilename: "ArchivoLargo".repeat(30) + ".pdf",
            },
            versions: [],
          }
        : material;
  else if (u.pathname.endsWith("/materials") || u.pathname.endsWith("/search"))
    body = {
      items: state === "empty" ? [] : [material],
      results: state === "empty" ? [] : [material],
      page: 1,
      pageSize: 20,
      total: state === "empty" ? 0 : 1,
    };
  return route.fulfill({ status: 200, json: body });
}
async function snapshot(page, name, width) {
  await page.waitForTimeout(250);
  await page.screenshot({
    path: path.join(out, `${width}-${name}.png`),
    fullPage: true,
  });
  const size = await page.evaluate(() => ({
    width: innerWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  assert.equal(
    size.scrollWidth,
    size.width,
    `${name}: desbordamiento a ${width}px`,
  );
  return size;
}
(async () => {
  const browser = await chromium.launch({
    headless: true,
    args: ["--no-sandbox"],
  });
  try {
    for (const width of [1440, 375, 320]) {
      const context = await browser.newContext({
        viewport: { width, height: 900 },
        locale: "es-CL",
        deviceScaleFactor: 1,
      });
      for (const [name, url, state] of [
        ["home", "/", "ready"],
        ["login", "/login", "ready"],
        ["register", "/register", "ready"],
        ["catalog", "/catalog", "ready"],
        ["catalog-empty", "/catalog", "empty"],
        ["catalog-error", "/catalog", "error"],
        ["catalog-loading", "/catalog", "loading"],
        ["search", "/search?q=datos", "ready"],
        ["search-empty", "/search?q=datos", "empty"],
        ["search-error", "/search?q=datos", "error"],
        ["search-loading", "/search?q=datos", "loading"],
        ["library", "/library", "ready"],
        ["library-empty", "/library", "empty"],
        ["library-error", "/library", "error"],
        ["upload", "/materials/upload", "ready"],
        ["detail", "/material/m1", "ready"],
        ["detail-long", "/material/m1", "long"],
        ["detail-missing", "/material/m1", "missing"],
        ["profile", "/profile", "ready"],
        ["not-found", "/ruta-inexistente", "ready"],
      ]) {
        if (
          process.env.RESUME &&
          report.scenarios.some((s) => s.width === width && s.name === name)
        )
          continue;
        const p = await context.newPage();
        const errors = [];
        p.on("pageerror", (e) => errors.push(e.message));
        await p.route("http://127.0.0.1:3000/**", (r) => api(r, state));
        await p.goto(origin + url);
        if (state === "error")
          await p.getByRole("alert").first().waitFor({ timeout: 20000 });
        else if (state === "missing")
          await p
            .getByText(/No encontramos este material/i)
            .first()
            .waitFor({ timeout: 20000 });
        else await p.waitForTimeout(350);
        if (name === "register")
          await p.getByRole("button", { name: "Crear cuenta" }).click();
        const size = await snapshot(p, name, width);
        assert.equal(errors.length, 0, `${name}: ${errors.join(", ")}`);
        assert.equal(
          (await p.locator("body").innerText()).includes(
            "Technical upstream failure",
          ),
          false,
        );
        report.scenarios.push({ name, state, ...size, errors });
        await p.close();
        console.log(width, name, "OK");
      }
      await context.close();
    }
    let p = await browser.newPage({
      viewport: { width: 375, height: 812 },
      locale: "es-CL",
    });
    await p.goto(origin + "/register");
    await p.getByRole("button", { name: "Crear cuenta" }).click();
    await p.waitForTimeout(100);
    assert.equal(await p.locator(":focus").getAttribute("name"), "name");
    report.interactions.focusFirstInvalid = true;
    const rgb = await p
      .getByText("Ingresa tu nombre completo.")
      .evaluate((e) => {
        const c = document.createElement("canvas").getContext("2d");
        c.fillStyle = getComputedStyle(e).color;
        c.fillRect(0, 0, 1, 1);
        return [...c.getImageData(0, 0, 1, 1).data].slice(0, 3);
      });
    const linear = rgb.map((v) => {
      v /= 255;
      return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
    });
    const ratio =
      1.05 /
      (linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722 + 0.05);
    assert(ratio >= 4.5);
    report.interactions.errorContrast = { rgb, ratio };
    for (const [label, value] of [
      ["Nombre completo", "Persona de prueba"],
      ["Correo electrónico", "persona@uct.cl"],
      ["Contraseña", "clave-segura-123"],
    ])
      await p.getByLabel(label, { exact: true }).fill(value);
    await p.getByLabel("Carrera", { exact: true }).selectOption("1");
    assert.equal(await p.getByRole("alert").count(), 0);
    report.interactions.registerAlertCleared = true;
    await snapshot(p, "register-corrected", 375);
    let mode = "error";
    await p.route("http://127.0.0.1:3000/**", async (r) => {
      if (mode === "slow")
        await new Promise((resolve) => setTimeout(resolve, 1000));
      return api(r, mode === "slow" ? "empty" : mode);
    });
    await p.goto(origin + "/catalog");
    await p
      .getByRole("button", { name: "Reintentar" })
      .waitFor({ timeout: 20000 });
    mode = "slow";
    await p.getByRole("button", { name: "Reintentar" }).click();
    await p.locator('[aria-busy="true"]').waitFor();
    await p.getByText("Todavía no hay asignaturas disponibles").waitFor();
    report.interactions.catalogRecovery = true;
    await p.goto(origin + "/catalog");
    await p.locator("body").click({ position: { x: 1, y: 1 } });
    const tabs = [];
    for (let i = 0; i < 9; i++) {
      await p.keyboard.press("Tab");
      tabs.push(
        await p.locator(":focus").evaluate((e) => ({
          tag: e.tagName,
          text: e.textContent || e.getAttribute("name"),
        })),
      );
      if ((await p.locator(":focus").textContent()) === "Mostrar filtros") {
        await p.keyboard.press("Enter");
        assert.equal(
          await p
            .getByRole("button", { name: "Ocultar filtros" })
            .getAttribute("aria-expanded"),
          "true",
        );
        report.interactions.keyboardFilters = true;
        break;
      }
    }
    assert(report.interactions.keyboardFilters);
    report.interactions.tabs = tabs;
    await snapshot(p, "keyboard-filters", 375);
    await p.getByText("Todavía no hay asignaturas disponibles").waitFor();
    await p.close();
    p = await browser.newPage({
      viewport: { width: 375, height: 812 },
      locale: "es-CL",
    });
    const results = report.interactions;
    await p.route("http://127.0.0.1:3000/**", async (r) => {
      if (r.request().method() === "POST")
        return r.fulfill({
          status: 401,
          json: { message: "Internal authorization exception" },
        });
      return api(r, "ready");
    });
    await p.goto(origin + "/materials/upload");
    await p.getByLabel("Título", { exact: true }).fill("Guía de prueba visual");
    await p.getByLabel("Año", { exact: true }).fill("2026");
    await p.locator('select[name="universityId"]').selectOption("u1");
    await p.locator('select[name="careerId"]').selectOption("c1");
    await p.locator('select[name="subjectId"]').selectOption("s1");
    await p
      .getByLabel("Tipo de material", { exact: true })
      .selectOption("LINK");
    await p
      .getByLabel("Enlace", { exact: true })
      .fill("https://example.com/guia");
    await p.getByRole("button", { name: "Revisar material" }).click();
    await p.getByRole("heading", { name: "Revisa tu material" }).waitFor();
    await p.waitForTimeout(100);
    assert.equal(await p.locator(":focus").textContent(), "Revisa tu material");
    await snapshot(p, "upload-review", 375);
    results.reviewFocus = true;
    await p.getByTestId("upload-submit-button").click();
    await p
      .getByRole("alert")
      .filter({ hasText: "Debes iniciar sesión" })
      .waitFor();
    assert(
      !(await p.locator("body").innerText()).includes(
        "Internal authorization exception",
      ),
    );
    await snapshot(p, "upload-auth-error", 375);
    results.uploadFriendlyError = true;
    await p.goto(origin + "/login");
    await p.getByLabel("Correo electrónico").fill("persona@uct.cl");
    await p.getByLabel("Contraseña", { exact: true }).fill("clave-segura-123");
    await p.getByRole("button", { name: "Ingresar", exact: true }).click();
    await p
      .getByRole("alert")
      .filter({ hasText: "El correo o la contraseña no son correctos." })
      .waitFor();
    await snapshot(p, "login-error", 375);
    results.loginFriendlyError = true;
    await p.close();
  } finally {
    fs.writeFileSync(
      path.join(out, "report.json"),
      JSON.stringify(report, null, 2),
    );
    await browser.close();
  }
})();
