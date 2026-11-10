# Cobertura de suites en CI

Auditoría de `main` (`317d347`) realizada el 2026-11-09. El workflow
`.github/workflows/pr-tests.yml` se ejecuta en PR hacia `main` y manualmente.
Esta tabla describe ejecución de suites, no porcentaje de cobertura de código.

| Suite | Estado previo | Ajuste |
| --- | --- | --- |
| Backend `src/**/*.spec.ts` | Incluida mediante `test:ci` | Sin cambios |
| Search E2E | Incluida en el `test:ci` de Search | Sin duplicarla en la matriz E2E |
| Gateway, Auth, Catalog y Material E2E | Incluidas en la matriz | Sin cambios |
| Material `test/*.integration.cjs` | Incluidas con PostgreSQL, MinIO y Catalog desechables | Sin cambios |
| `backend/scripts/api-docs.test.cjs` | Fuera de CI | Agregada al job backend |
| Auth `user-persistence.integration.cjs` | Fuera de CI | Agregada al job E2E de Auth, con su base migrada |
| Gateway `test/*.integration.cjs` | Fuera de CI | Agregadas después del build en el job de integración |
| Web `*.integration.test.tsx` | Solo Catalog; Search excluida de ambos jobs | Selección por sufijo para ejecutar todas |
| Web, resto de Vitest | Incluidas | Sin cambios |
| Web lint y formato | Fuera de CI | Job `frontend-quality` con `npm run lint` y `npm run format:check` sobre `web/` |
| `.github/scripts/web-gateway-regression.cjs` | Fuera de CI | Job con Chromium, servicios desechables y navegación de materiales habilitada |
| Mobile `test/` | Incluidas salvo pruebas optativas | Sin cambios |

La suite de persistencia de Auth usa ahora `.prisma/auth-client`, igual que el
servicio. El fixture de Gateway/Material incorpora `CatalogPort` y un UUID válido
para la asignatura; conserva los dobles de persistencia, almacenamiento y autor
que ya utilizaba. La validación real contra Catalog sigue en las suites de Material.

## Pruebas móviles que siguen fuera de la ejecución automática

- `mobile/test/integration/gateway_live_test.dart`: requiere
  `RUN_GATEWAY_SMOKE=true` y Gateway real; también contiene un escenario con
  servicios caídos controlado por `GATEWAY_SERVICES_UNAVAILABLE`.
- `mobile/test/integration/material_upload_live_test.dart`: requiere
  `RUN_MATERIAL_UPLOAD_SMOKE=true`, referencias académicas y un PDF de prueba,
  además de servicios y contexto de autor válidos.
- `mobile/integration_test/gateway_native_smoke_test.dart`: requiere dispositivo
  o emulador, servicios con datos preparados y `RUN_NATIVE_GATEWAY_SMOKE=true`.
- `mobile/integration_test/material_download_native_test.dart`: requiere
  dispositivo o emulador con plugins de archivos y apertura nativa.

Los comandos y parámetros están en [mobile/README.md](../mobile/README.md).
Automatizar estos recorridos requiere preparar el entorno móvil y sus datos;
`flutter test --coverage` no constituye evidencia de ejecución de esas suites.

## Validación local del ajuste

- Build completo de backend correcto.
- Contratos de documentación API correctos.
- Integración frontend: 2 archivos, 15 pruebas correctas.
- Integración Gateway: 29 pruebas correctas, sin omisiones.
- YAML del workflow parseado y `git diff --check` sin errores.
- Lint y verificación de formato de web correctos. Se excluyen los artefactos
  generados `dist/` y `coverage/`; CI verifica el formato sin modificar archivos.
- Pendiente de ejecución en GitHub Actions: persistencia Auth con PostgreSQL
  desechable y regresión de navegador con Docker. Docker local no inicia por un
  error de confinamiento de Snap/AppArmor. Flutter no está disponible localmente.
