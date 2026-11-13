# Revisión y aceptación de contratos Quality

Estado: propuesta. Los escenarios de esta matriz son obligaciones para la implementación futura; no se presentan como pruebas E2E ya ejecutadas.

## 1. Trazabilidad de la tarea

| Criterio solicitado | Evidencia documental |
| --- | --- |
| DTO/endpoints de moderación, notas, reportes y favoritos | quality-contracts.md §§3–7; quality.openapi.json |
| Tabla PENDING_REVIEW/PUBLISHED/REJECTED/RETIRED | quality-publication.md §2; MaterialStatus en ambos OpenAPI |
| Permisos STUDENT/MODERATOR/ADMIN | quality-contracts.md §2 y x-allowed-roles por operación |
| Errores 401/403/404/409 | quality-contracts.md §8 y componentes/respuestas OpenAPI |
| Idempotencia de moderación | quality-publication.md §§4–5; Idempotency-Key; operationId y recibos |
| Consulta/descarga de pendientes autorizada | quality-contracts.md §4; rutas privadas Material y scopes |
| Aplicación de cambios en Material y Search | quality-publication.md §§1,4,6,7 |
| Ocultos ausentes de búsqueda/descarga pública | quality-publication.md §7, incluyendo frontera temporal |
| Contratos accesibles y acordados con Web/Mobile | Archivos versionados y registro de revisión de §4 de este documento |

## 2. Comprobaciones documentales de este PR

Desde la raíz del repositorio:

```powershell
node scripts/validate-quality-contracts.cjs
git diff --check
```

El script incluido comprueba referencias locales, rutas/parámetros, seguridad declarada, roles, estados canónicos, claves de idempotencia, endpoints esenciales y enlaces Markdown locales. Usa solo Node. No levanta servicios, no accede a PostgreSQL y no sustituye un validador completo de OpenAPI ni pruebas de autorización.

Los dos archivos fueron comprobados adicionalmente como OpenAPI 3.0.3 y sus ejemplos de componentes contra sus esquemas durante la preparación del paquete. El revisor puede abrir cada JSON en su visor/editor OpenAPI aprobado para repetir la validación de especificación. No se ha probado la ejecución de estas rutas futuras.

## 3. Escenarios exigidos para la implementación posterior

| ID | Escenario | Resultado esperado |
| --- | --- | --- |
| AUTH-01 | Token ausente, mock/alg:none, inválido, expirado o revocado en ruta privada | 401; WWW-Authenticate; sin datos ni escritura |
| AUTH-02 | Token válido STUDENT consulta pendientes o descarga privada | 403; sin archivo ni metadatos |
| AUTH-03 | MODERATOR/ADMIN activo consulta snapshot privado | 200 con revision; sin storageKey |
| AUTH-04 | Cuenta inactiva o headers x-role/x-user-id falsificados | Sin elevación de privilegios; cuenta inactiva 403 |
| AUTH-05 | Acceso directo al servicio saltando Gateway | Mismas comprobaciones de autorización |
| AUTH-06 | JWT usuario en endpoint interno, aserción de servicio falsa o scope incorrecto | 401 por credencial inválida; 403 por scope insuficiente |
| AUTH-07 | Actor decide sobre material propio, incluido ADMIN | 403 |
| MOD-01 | Aprobar PENDING_REVIEW con revision vigente | 202; luego APPLIED/PUBLISHED, verified=false |
| MOD-02 | Rechazar pendiente con motivo | APPLIED/REJECTED; sin visibilidad pública |
| MOD-03 | Retirar publicado | APPLIED/RETIRED, verified=false |
| MOD-04 | Reabrir rechazado/retirado por moderador autorizado | APPLIED/PENDING_REVIEW; no publica automáticamente |
| MOD-05 | VERIFY publicado no verificado; REVOKE_VERIFICATION verificado | Conserva PUBLISHED; cambia verified según acción |
| MOD-06 | Transición inválida o falta motivo obligatorio | 409 o 400 respectivamente; sin efectos |
| MOD-07 | Contenido, enlace o estado cambia desde snapshot | 409 STALE_REVISION o operación FAILED por conflicto posterior a aceptación |
| MOD-08 | Dos decisiones distintas sobre misma revision | Como máximo una aplica; la otra conflicto |
| IDEM-01 | Misma clave y payload, incluso después de perder respuesta | Una operación, una evidencia y un efecto; replay devuelve misma operación |
| IDEM-02 | Misma clave con otro material, motivo o action | 409 IDEMPOTENCY_CONFLICT |
| IDEM-03 | Dos workers entregan simultáneamente mismo operationId | Un recibo y un efecto; mismo resultado |
| IDEM-04 | Material confirma y Quality pierde la respuesta | Reintento recupera recibo; no duplica ni revierte |
| IDEM-05 | GET recibo devuelve 404 mientras primer PUT sigue en curso | No declarar rollback; reintentar mismo PUT |
| IDEM-06 | Material caído tras aceptación en Quality | Operación pendiente durable; se recupera después; UI no anuncia publicación |
| IDEM-07 | Actor pierde rol después de aceptación durable | Completar conforme a autorización aceptada; no permitir nuevas decisiones ni consultas privadas sin permiso actual |
| VIS-01 | Cada estado no público por listado/detalle/descarga | Excluido de listado; detalle y descarga 404 |
| VIS-02 | Versión de otro material o inexistente | 404 incluso en descarga privada |
| VIS-03 | Buscar luego del commit confirmado de retiro | No incluir material retirado |
| VIS-04 | LINK pendiente/rechazado/retirado | No exponer externalLink por rutas públicas |
| VIS-05 | Descarga privada | attachment/MIME/length correctos; no-store; sin URL pública ni storageKey |
| VIS-06 | Material publicado con varias versiones | Históricas accesibles según contrato; revisión cubre el agregado |
| VIS-07 | Favorito de material posteriormente oculto | available=false sin metadatos ni archivo; no inferir estado privado |
| VIS-08 | Dependencia falla al comprobar visibilidad | 502/503; no servir caché pública ni asumir visibilidad |
| RAT-01 | score 1 y 5; 0,6,1.5 y cadena "5" | Extremos aceptados; otros 400; DB conserva CHECK |
| RAT-02 | Dos PUT propios y mismo PUT repetido | Una nota vigente; repetición idéntica no cambia updatedAt |
| RAT-03 | Calificar material propio | 403 |
| RAT-04 | Eliminar nota propia ausente/de material oculto | 204; no revela información privada |
| REP-01 | OTHER sin detalles o motivo desconocido | 400 |
| REP-02 | Dos reportes abiertos del mismo usuario/material, distintas claves | Uno aceptado; otro 409 incluso bajo concurrencia |
| REP-03 | Repetir creación o PATCH con misma clave/payload | Mismo recurso/snapshot, sin reabrir ni duplicar |
| REP-04 | Usuario consulta reporte ajeno | 404; moderador autorizado sí accede |
| REP-05 | Reportero/autor del material intenta resolver | 403 |
| REP-06 | Dos PATCH con expectedUpdatedAt igual | Uno aplica; otro 409; repetir clave original devuelve snapshot |
| REP-07 | Resolver reporte | No altera Material; retiro requiere decisión separada |
| FAV-01 | Repetir PUT/DELETE propio | Sin duplicados; DELETE siempre 204 si autenticado y UUID válido |
| PAGE-01 | Página fuera de rango o sin registros | 200, items=[], total correcto |
| PAGE-02 | Mismo createdAt entre registros | Desempate id DESC, resultado reproducible sin cambios de datos |
| PAGE-03 | Parámetro desconocido, vacío, repetido o offset excesivo | 400 |
| MIG-01 | Datos existentes con WITHDRAWN | Adaptación a RETIRED conserva filas y visibilidad oculta |
| MIG-02 | migrate deploy repetido | No pierde datos ni reaplica efectos |

## 4. Registro de acuerdo

Completar con personas reales, fecha y enlace al comentario/aprobación. No marcar una casilla solo por pasar validación de JSON.

| Área | Revisor/a | Fecha | Evidencia | Estado |
| --- | --- | --- | --- | --- |
| Backend / Material | Pendiente | — | — | Pendiente |
| Backend / Quality | Pendiente | — | — | Pendiente |
| Auth / Gateway | Pendiente | — | — | Pendiente |
| Search | Pendiente | — | — | Pendiente |
| Web | Pendiente | — | — | Pendiente |
| Mobile | Pendiente | — | — | Pendiente |

Acuerdos explícitos solicitados:

- [ ] RETIRED es el nombre público definitivo; existe plan de adaptación de WITHDRAWN.
- [ ] Se aceptan matriz de permisos, prohibición de autorrevisión/autocalificación y tramitación de reportes propios.
- [ ] Se acepta publicación a nivel de agregado con versiones históricas; cambios relevantes vuelven a revisión.
- [ ] REOPEN corresponde a moderadores; el reenvío especializado del autor queda para otro contrato de Material.
- [ ] Se acepta 202/operación consultable y la semántica de replay, fallos y concurrencia.
- [ ] Se acepta que decisiones duraderamente autorizadas se completen aunque después cambie el rol del actor.
- [ ] Se acuerdan JWT real de usuario, emisor/audiencia/actividad y aserción firmada de Quality para Material.
- [ ] Se acepta conservación de notas al republicar y de referencias propias a favoritos ocultos.
- [ ] Web/Mobile identifican estados pendiente/aplicado/fallido y no interpretan un 202 como publicación.
- [ ] Los clientes tienen acceso a ambos documentos y al OpenAPI público antes de integrar endpoints reales.

Después del acuerdo: actualizar el estado de documentos a ACORDADO, registrar la versión/fecha, mantener historial mediante Git y crear/enlazar tareas de implementación. El contrato interno se comparte con Backend; Web/Mobile no deben llamarlo.
