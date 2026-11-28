# Revisión visual, accesibilidad y errores finales — #269

Validación realizada el 16 de noviembre de 2026 sobre `main` en `57e6e9a`,
recuperando los cambios pendientes de #374 hasta `536bddc`.

## Cambios y criterios de aceptación

- Formularios: etiquetas obligatorias en `Input` y `Select`, asociación de ayuda y
  errores, foco en el primer campo inválido del registro. Al corregir los campos,
  desaparece la alerta general sin necesidad de volver a enviar.
- Contraste: mensajes de validación con `text-red-700`; medición del color
  renderizado RGB(193, 0, 7) sobre blanco: **6,42:1**, superior al mínimo de 4,5:1
  para texto normal. Antes usaban `text-red-500` (aproximadamente 3,81:1).
- Estados: catálogo con carga anunciada, error recuperable mediante Reintentar y
  mensajes distintos para catálogo vacío y búsqueda sin coincidencias.
- Errores técnicos: login solo presenta mensajes controlados; una configuración
  ausente o JSON inválido reciben un mensaje genérico, y HTTP 401 explica que las
  credenciales no son correctas. No se muestra `Error.message` arbitrariamente.
- Presentación: se recuperan navegación adaptable, pie de página, perfil pendiente,
  página 404, ajustes del formulario de subida y etiquetas de tipos de material.
  El formateador compartido vive en un módulo separado para cumplir Fast Refresh.
- Integración: se conservan los filtros de búsqueda, estados de materiales,
  historial de versiones y manejo de descarga ya incorporados a `main`.

## Resultado de las verificaciones

| Verificación                                                 | Resultado                          |
| ------------------------------------------------------------ | ---------------------------------- |
| `cd web && npm run test:run`                                 | 33 archivos, 241 pruebas aprobadas |
| `cd web && npm run build`                                    | Aprobado                           |
| `cd web && npm run lint`                                     | Aprobado                           |
| `cd web && npm run format:check`                             | Aprobado                           |
| Chromium: 20 vistas/estados en 1440, 375 y 320 px            | 60 escenarios aprobados            |
| Desbordamiento horizontal del documento                      | Ninguno en esos escenarios         |
| Excepciones JavaScript no capturadas                         | Ninguna en esos escenarios         |
| Registro: foco y retirada de alerta                          | Aprobado                           |
| Catálogo: error → carga → respuesta vacía                    | Aprobado                           |
| Tab y Enter: navegación y filtros móviles                    | Aprobado                           |
| Subida: resumen con foco y error de autenticación entendible | Aprobado                           |
| Login: error de credenciales entendible                      | Aprobado                           |

Las pruebas de regresión cubren específicamente la alerta persistente, errores de
configuración y JSON del login, HTTP 401 y recuperación del catálogo. Las pruebas
existentes de búsqueda, navegación, detalle, descarga y subida también pasan.

Las 20 vistas/estados son: inicio, login, registro inválido, catálogo con datos,
catálogo vacío, catálogo con error, catálogo cargando, búsqueda con datos, búsqueda
vacía, búsqueda con error, búsqueda cargando, biblioteca con datos, biblioteca
vacía, biblioteca con error, subida, detalle con historial, detalle con cadenas
largas, material inexistente, perfil pendiente y página inexistente.

## Evidencia visual

- [Registro: errores y contraste](evidencias/revision-visual-269/registro-errores.png)
- [Registro: campos corregidos sin alerta](evidencias/revision-visual-269/registro-corregido.png)
- [Búsqueda con filtros a 320 px](evidencias/revision-visual-269/busqueda-320.png)
- [Catálogo vacío](evidencias/revision-visual-269/catalogo-vacio.png)
- [Detalle e historial de versiones](evidencias/revision-visual-269/detalle-versiones.png)
- [Subida: error de autenticación](evidencias/revision-visual-269/subida-error.png)
- [Resultados del navegador](evidencias/revision-visual-269/resultados.json)

## Reproducir la revisión en navegador

El script `tools/review-269-visual.cjs` utiliza Playwright con respuestas HTTP
controladas. No necesita servicios externos ni modifica datos del backend.
Instalar la herramienta fuera del repositorio evita cambiar las dependencias web:

```bash
npm install --prefix /tmp/apuntes-269-tools playwright@1.63.0
PLAYWRIGHT_BROWSERS_PATH=/tmp/apuntes-269-browsers \
  node /tmp/apuntes-269-tools/node_modules/playwright/cli.js install chromium --only-shell
```

Iniciar Vite en una terminal:

```bash
cd web
VITE_API_URL=http://127.0.0.1:3000/api/v1 npm run dev -- --host 127.0.0.1 --port 5174 --strictPort
```

Desde la raíz del repositorio, ejecutar en otra terminal:

```bash
PLAYWRIGHT_MODULE=/tmp/apuntes-269-tools/node_modules/playwright \
PLAYWRIGHT_BROWSERS_PATH=/tmp/apuntes-269-browsers \
WEB_URL=http://127.0.0.1:5174 \
VISUAL_OUTPUT=/tmp/apuntes-269-visual \
node tools/review-269-visual.cjs
```

El script genera capturas de página completa y `report.json`, y falla si detecta
un desbordamiento, una excepción JavaScript, contraste insuficiente o una
regresión en las interacciones comprobadas.

## Alcance y límites

Revisión de la **web**, incluidos anchos móviles; no corresponde a Flutter.
Se utilizó Chromium Headless con locale `es-CL` y respuestas simuladas del API.
Esto verifica la presentación y las interacciones, no sustituye una regresión
contra servicios reales ni una auditoría completa con lectores de pantalla o
Safari/Firefox.

El registro conserva el alcance de la interfaz original: valida los datos y
explica que todavía no envía cuentas desde esta página. La conexión del registro,
la persistencia de sesión del login y la activación de Google quedan fuera de
esta tarea visual. El catálogo lateral mantiene sus filtros simulados existentes;
los selectores de búsqueda y subida conservan su integración con Catalog.
