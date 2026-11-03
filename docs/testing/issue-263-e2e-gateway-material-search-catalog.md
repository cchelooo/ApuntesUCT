# Ejecución real E2E #263 — Gateway → Material/Search/Catalog

- Fecha local: 2026-11-02, 21:15 (America/Santiago).
- Inicio de ejecución final UTC: 2026-11-03T00:15:19Z.
- Rama: feature/263-e2e-gateway-material-search-catalog.
- HEAD al ejecutar: 5a81772f1590b7af58211b7396698d93f9d08403.
- Resultado: **operaciones disponibles validadas en dos escenarios**: creación en `PENDING_REVIEW` y consultas sobre un dato de prueba previamente `PUBLISHED`. La transición de aprobación queda pendiente de Quality, aún no implementado; no es un defecto de Material.
- Cliente: exclusivamente `http://localhost:3000`; el script rechaza redirecciones.
- Servicios reales: Gateway, Auth, Catalog, Material y Search; PostgreSQL y MinIO locales. Se reutilizaron los builds locales existentes de Gateway, Catalog, Material y Search; Auth se compiló durante la preparación. No se certificó una reconstrucción limpia de todos los servicios desde HEAD.

## Evidencia

- [Resultado final](issue-263-real-result.json): solicitudes, códigos HTTP, respuestas de creación/error/búsqueda y comprobaciones del material. Catálogo y listado están resumidos; el token está redactado.
- [Primer intento: autor ausente](issue-263-initial-failure.json).
- [Segundo intento: almacenamiento sin configurar](issue-263-author-failure.json).
- [Script ejecutado](../../tools/e2e-263-real.cjs).

Material retenido para inspección:

- ID: `2007cb26-e081-4609-b34c-0fc9c40c57a4`.
- Título: `E2E263-1793664919795`.
- Estado devuelto por creación: `PENDING_REVIEW`.
- Archivo enviado: `e2e-263.pdf`, 77 bytes; SHA-256 registrado en el JSON.

## Escenario A: creación y restricciones de visibilidad antes de Quality

| Paso | HTTP | Comprobación |
| --- | --- | --- |
| Health y login por Gateway | 200 / 200 | Login mock disponible; no acredita autenticación real |
| Consultar árbol y profesores | 200 / 200 | IDs académicos reales obtenidos del catálogo |
| Crear material multipart | 201 | `isSimulatedResponse=false`, ID real, `PENDING_REVIEW` |
| Listar material | 200 | El material recién creado no aparece en la primera página de 100 elementos |
| Consultar detalle | 404 | `Material no encontrado.` |
| Descargar | 404 | No se obtuvo PDF; no fue posible comparar bytes/hash |
| Buscar título único | 200 | `total=0`, `results=[]` |
| Consultar versiones mediante detalle | 404 | No se pudo obtener el historial |

El script original finalizó con código 1 porque esperaba consultar públicamente el material recién creado. Con el alcance aclarado, los 404 y la ausencia en listado/búsqueda son coherentes con `PENDING_REVIEW`; el script comprueba el recorrido continuo, todavía no disponible sin Quality. No deben interpretarse como una regresión de Material.

## Incidencias y causa

1. **Autor local no configurado:** primer POST devuelve 401, `Se requiere un contexto de autor válido.` El token del login mock no autoriza la creación. Para continuar se activó temporalmente el mecanismo existente de desarrollo (`NODE_ENV=development`, `MATERIAL_LOCAL_AUTHOR_ENABLED=true`, `MATERIAL_LOCAL_UPLOADER_ID=00000000-0000-4000-8000-000000000092`). No se implementó autenticación nueva.
2. **MinIO sin configurar en Material:** segundo POST devuelve 502, `No se pudo almacenar el archivo.` Las variables `MINIO_ENDPOINT`, `MINIO_PORT`, `MINIO_BUCKET`, `MINIO_ACCESS_KEY` y `MINIO_SECRET_KEY` estaban ausentes del `.env` del servicio. Para la ejecución final se inyectó la conexión a MinIO local y se aseguró el bucket privado `materials`. Las credenciales locales existentes solo se usaron en memoria; no se copiaron a la evidencia.
3. **Contrato de creación incorrecto en la guía anterior:** el DTO acepta `year=2026` y `type=DOCUMENT`, no `academicYear`/`materialType=APUNTE`. El script usa el contrato de POST vigente. Los nombres del contrato GET son distintos.
4. **Dependencia pendiente de Quality (comportamiento esperado, no defecto de Material):** `CreateMaterial` guarda `PENDING_REVIEW`, mientras que `MaterialsService` exige `PUBLISHED` en listado, detalle y descarga. Search consume el listado público. No se encontró un endpoint de publicación en Material en esta rama. Por eso crear y consultar inmediatamente el mismo material no completa el flujo solicitado. El usuario confirmó que Quality será responsable de aprobar y aún no está implementado. Se separó la prueba en creación pendiente y operaciones públicas sobre un dato de prueba ya publicado. No se cambió el estado directamente en PostgreSQL para hacer pasar la prueba.

## Reproducción

Requiere Node con `fetch`, `FormData` y `Blob`, bases migradas, catálogo activo con asignaturas, un tipo de Material activo llamado `DOCUMENT`, bucket privado de MinIO y servicios reales en 3000/3001/3002/3003/3005. Configurar los `.env` siguiendo los ejemplos de cada servicio. Para Material, usar las variables MinIO indicadas arriba y el contexto local de autor exclusivamente en desarrollo. El login es simulado por el servicio Auth existente.

Desde la raíz del repositorio, con los servicios levantados:

```bash
E2E_OUTPUT=/tmp/apuntes-e2e-263-final node tools/e2e-263-real.cjs
```

El script obtiene IDs del catálogo, crea un título único y conserva el material para inspección. Cada repetición exitosa del POST crea otro material. Guarda `report.json` y `original.pdf`; solo guarda `download.pdf` si la descarga responde 200 y compara sus bytes y SHA-256 con el original. No modifica bases directamente, no accede a microservicios desde el cliente y no almacena el token en el reporte.

## Estado final del entorno

Se detuvo Auth iniciado para esta ejecución y se restauró Material con su comando y configuración originales, sin las variables temporales de autor/MinIO. Los demás servicios y la infraestructura existente permanecieron activos. El material de prueba y su archivo se conservaron para revisión. No se modificó código funcional ni se publicó el material.

## Escenario B: operaciones públicas sobre dato de prueba PUBLISHED

- Fecha local: 2026-11-02 (America/Santiago); hora UTC exacta en el reporte.
- Resultado: **APROBADO**, script finaliza con código 0.
- [Reporte de ejecución](issue-263-published-result.json).
- [Script reproducible](../../tools/e2e-263-published.cjs).
- Material existente: `1b28b5dd-9095-421a-a887-66a77c27521d`.
- Título: `Estructuras de Datos — Guía de pilas y colas (prueba temporal)`.
- Versión: `e8050a46-df13-4840-8597-23b25931c426`, número 1.
- Archivo: `apuntesuct-prueba-temporal.pdf`, 870 bytes.
- SHA-256: `c5d85f8fb269a46e5de1040af44c1f4bd084e4b9f38d260f46ced5caa0fab48c`.

No se creó ni publicó este dato durante el escenario B: ya existía y estaba marcado como material temporal de pruebas. No se modificó su estado ni el del material del escenario A. El origen de su publicación previa no forma parte de esta prueba.

| Comprobación | Resultado |
| --- | --- |
| Listado por Gateway | 200; contiene el ID publicado |
| Detalle e historial | 200; `PUBLISHED`, versión 1 y `currentVersion` coincidente |
| Contexto académico en Catalog | 200; asignatura correspondiente encontrada |
| Búsqueda por título | 200; devuelve el mismo ID con nombres de asignatura y universidad |
| Descarga actual | 200; PDF, `Content-Disposition: attachment`, 870 bytes y SHA-256 esperado |
| Descarga con `versionId` explícito | 200; bytes idénticos a la descarga actual |

El checksum de referencia se obtuvo mediante una lectura limitada del registro de la versión en PostgreSQL como preparación de la prueba. Esa lectura administrativa no es una solicitud del cliente: todas las operaciones del escenario B usan exclusivamente `http://localhost:3000`. El cliente no conoce la dirección de MinIO ni consulta microservicios directamente.

Material se conectó temporalmente al MinIO local para descargar el archivo; después se restauró su configuración original. No se habilitó autor local para estas operaciones de lectura. La configuración persistente de MinIO sigue siendo un prerrequisito pendiente del entorno original.

Reproducir con los servicios y MinIO configurados, desde la raíz:

```bash
E2E_MATERIAL_ID=1b28b5dd-9095-421a-a887-66a77c27521d \
E2E_EXPECTED_SHA256=c5d85f8fb269a46e5de1040af44c1f4bd084e4b9f38d260f46ced5caa0fab48c \
node tools/e2e-263-published.cjs
```

El script es de solo lectura, guarda el PDF y el reporte en `/tmp/apuntes-e2e-263-published` y devuelve código 1 si alguna comprobación falla. Para otro dato de prueba se deben proporcionar su ID y un hash esperado independiente.

## Conclusión

Catalog, creación real de Material y operaciones públicas de Material/Search se validaron por el Gateway en dos escenarios separados. **La creación correcta conserva `PENDING_REVIEW`; las consultas correctas usan un material previamente `PUBLISHED`.** La aprobación y el recorrido continuo con el mismo material nuevo quedan pendientes de implementar Quality. Esta evidencia no acredita una aprobación simulada ni reemplaza la futura prueba de integración con Quality.

Según la planificación del Sprint 2, se permiten datos publicados de prueba y la aprobación/rechazo corresponde a Quality en Sprint 3. Por ello, Quality no bloquea la aceptación de #263 en este Sprint: los seis pasos se comprobaron por el puerto 3000 en los dos escenarios descritos y las incidencias quedaron registradas. La configuración local de autor y MinIO es un prerrequisito de reproducción, no una nueva funcionalidad exigida por esta tarea.
