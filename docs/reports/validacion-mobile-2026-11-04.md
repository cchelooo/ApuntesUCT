# Validación de builds y ejecución integrada Mobile

Fecha: **04-11-2026**, zona `America/Santiago`. Base: `origin/main`
`98651746ac8f5128dacfba0179a3bd47bc6d9d3b`. Rama de validación:
`test/278-mobile-integrated-builds`.

## Entorno y reproducción

- macOS 27.0.1 arm64; Flutter **3.47.2**, Dart **3.13.2**.
- Android Emulator `Medium_Phone`, Android **17 / API 37**, arm64.
- Xcode **27.2**, CocoaPods **1.17.0**; iPhone 17 Pro Simulator, **iOS 26.5**.
- Node.js **26.0.0**; Docker **29.7.2**; PostgreSQL 17 y MinIO reales en
  contenedores desechables. No se usó Kubero ni un teléfono físico.

Los [comandos completos del README](../../mobile/README.md#validación-integrada-en-android-e-ios)
preparan los servicios y repiten los builds y el recorrido. El
[script del entorno](../../mobile/tool/start_gateway_smoke.cjs) usa los paquetes
INT2 existentes sin modificarlos. Crea recursos `qa278-*`, aplica migraciones en
bases propias y deja sus logs y `fixture.json` fuera del repositorio.

## Resultados

| Comprobación | Resultado |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test test_driver` | Aprobado, 184 archivos, 0 cambios pendientes |
| `flutter analyze` | Aprobado, sin incidencias |
| `flutter test` | 526 aprobadas; 5 pruebas HTTP optativas omitidas |
| `flutter build apk --debug` | Aprobado, APK debug generado |
| Instalación/arranque del APK normal | Aprobado en Android Emulator; login renderizado |
| `flutter build ios --simulator --debug` | Aprobado; `Runner.app` generado |
| Instalación/arranque de `Runner.app` normal | Aprobado en iPhone 17 Pro Simulator iOS 26.5; login renderizado |
| `flutter drive` contra Gateway real, Android | Aprobado; seis peticiones `200`, seis capturas y PDF guardado |
| `flutter drive` contra Gateway real, iOS | Aprobado; seis peticiones `200`, seis capturas y PDF guardado |
| Health de Gateway/Auth/Catalog/Material/Search | Los cinco respondieron `200` |
| Limpieza del entorno | Ambos contenedores propios retirados con sus volúmenes |

Se aplicó `dart format` a los 24 archivos preexistentes que no cumplían el
formato del SDK. No se cambió la lógica de producción. El directorio `.kotlin/`
generado por la compilación Android se excluyó del control de versiones.

El APK normal quedó en `mobile/build/app/outputs/flutter-apk/app-debug.apk`
(173.327.105 bytes; el artefacto no se versiona). SHA-256:

```text
a666044cba0ec10ba4d4b3ddeb4911a4f16b3e25f7b92b2cd3ae89d6a19070db
```

`flutter drive` vuelve a compilar el target de pruebas y reemplaza el APK de esa
carpeta. El hash anterior corresponde al build normal de `lib/main.dart`, no
al ejecutable instrumentado de la prueba.

## Evidencia del recorrido

La corrida usa Gateway `127.0.0.1:50461` desde iOS/host y su alias
`10.0.2.2:50461` desde Android. El puerto es efímero. Material de prueba:
`a7f01fd8-c769-4b86-a89b-c258ebd27d79`, título `Integracion278`, asignatura
`Asignatura QA278`. PDF: **414 bytes**, SHA-256:

```text
a2b4945b6565b105cbf8ab4dc1d86bfc925d1e3eaa91cfb6ea770d292c333d28
```

| Recorrido | Solicitud comprobada por Mobile | Resultado observado |
| --- | --- | --- |
| Login | `POST /api/v1/auth/login` | `200`; navegación a Inicio, autenticación simulada en Backend |
| Catálogo | `GET /api/v1/catalog` | `200`; asignatura del fixture visible |
| Listado | `GET /api/v1/materials?page=1&pageSize=5` | `200`; ID del fixture presente |
| Búsqueda | `GET /api/v1/search?q=Integracion278&page=1&pageSize=5` | `200`; mismo ID presente |
| Tarjeta → detalle | `GET /api/v1/materials/{id}` | `200`; ruta con ese ID, versión actual visible |
| Descarga | `GET /api/v1/materials/{id}/download?versionId={id-version}` | `200`; PDF guardado en caché nativa, bytes idénticos |

Los resultados de ambas plataformas están en
[Android/report.json](evidence/mobile-2026-11-04/android/report.json) e
[iOS/report.json](evidence/mobile-2026-11-04/ios/report.json). Los
[resultados de comandos y hashes de fuentes](evidence/mobile-2026-11-04/validation.json)
y el [registro del stack, imágenes y limpieza](evidence/mobile-2026-11-04/stack.json)
permiten identificar esta ejecución. Los logs completos y el APK permanecen
fuera de Git; el script y el README permiten regenerarlos.

| Captura | Android | iOS Simulator |
| --- | --- | --- |
| Arranque del build normal | [PNG](evidence/mobile-2026-11-04/arranque-android.png) | [PNG](evidence/mobile-2026-11-04/arranque-ios.png) |
| Login de la suite | [PNG](evidence/mobile-2026-11-04/android/login.png) | [PNG](evidence/mobile-2026-11-04/ios/login.png) |
| Catálogo | [PNG](evidence/mobile-2026-11-04/android/catalogo.png) | [PNG](evidence/mobile-2026-11-04/ios/catalogo.png) |
| Listado | [PNG](evidence/mobile-2026-11-04/android/listado.png) | [PNG](evidence/mobile-2026-11-04/ios/listado.png) |
| Búsqueda | [PNG](evidence/mobile-2026-11-04/android/busqueda.png) | [PNG](evidence/mobile-2026-11-04/ios/busqueda.png) |
| Detalle | [PNG](evidence/mobile-2026-11-04/android/detalle.png) | [PNG](evidence/mobile-2026-11-04/ios/detalle.png) |
| Descarga guardada | [PNG](evidence/mobile-2026-11-04/android/descarga.png) | [PNG](evidence/mobile-2026-11-04/ios/descarga.png) |

## Integración real y límites

El fixture académico y el PDF son datos sintéticos almacenados en PostgreSQL y
MinIO reales. La preparación envía `POST /materials` por Gateway, recibe `201`
y `PENDING_REVIEW`, verifica la descarga y cambia el estado a `PUBLISHED`
directamente en su base desechable. **Esto no valida moderación.**

La [suite nativa](../../mobile/integration_test/gateway_native_smoke_test.dart)
usa `MyApp`, rutas, providers, repositorios Dio y plugins reales. El driver
[guarda las capturas y el registro HTTP](../../mobile/test_driver/gateway_smoke.dart)
sin tokens ni contraseñas. Se entra a Materiales desde Inicio y al detalle
pulsando la tarjeta; catálogo se abre mediante su ruta de producción.

- El login es HTTP real, pero Auth devuelve un JWT simulado sin comprobar
  credenciales: no es validación de autenticación o autorización real.
- `/materials` integra listado, búsqueda y detalle. `/search` y `/library`
  siguen pendientes; Inicio/Perfil conservan datos de ejemplo y otras operaciones
  de Auth usan simulaciones mientras falten sus endpoints.
- El recorrido nativo descarga y guarda bytes en caché. No inicia un visor
  externo ni valida subida/versionado desde la interfaz; los prepara o cubre
  mediante otras suites. `material_download_native_test.dart` usa transporte
  controlado y no es evidencia de un backend real.
- `flutter doctor` advierte licencias Android de estado desconocido y runtime
  iOS 27.2 ausente. No impidieron los builds ni los arranques con el SDK Android
  instalado y el runtime iOS 26.5 disponible. No se aceptaron licencias ni se
  descargaron runtimes para esta validación.
- `open_filex` todavía usa CocoaPods y genera un aviso de migración pendiente
  a Swift Package Manager. No bloqueó el build del simulador.
- Se observó que el nombre acentuado del fixture, `Guía278.pdf`, llega como
  `GuÃ­a278.pdf` en los metadatos del servicio. La descarga conserva los bytes;
  esta corrida no certifica la codificación del nombre multipart de INT2.
- No se generó IPA firmado ni se probó distribución de App Store/Play Store.
- #263 está cerrada; #262 continúa abierta al consultar GitHub. La validación
  usa los contratos disponibles en main y no certifica la entrega documental
  pendiente de INT2.
