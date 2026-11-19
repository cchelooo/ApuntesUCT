# Revisión y aceptación de contratos Quality

Estado: **PROPUESTO — pendiente de aceptación completa**.

Tarea: [#444 — Definir contratos Quality y reglas de visibilidad/publicación](https://github.com/cchelooo/ApuntesUCT/issues/444).

Este documento registra la cobertura de la tarea, las decisiones que deben
acordarse y la evidencia de aprobación de Backend, Web y Mobile.

Los escenarios de prueba corresponden a la implementación futura. No se
presentan como pruebas E2E ya ejecutadas.

La validación documental, la implementación de modelos de cliente y la
aprobación del contrato son evidencias diferentes. Ninguna sustituye
automáticamente a las otras.

## 1. Trazabilidad de la tarea

| Criterio solicitado | Evidencia documental |
| --- | --- |
| DTO y endpoints de moderación, calificaciones, reportes y favoritos | [quality-contracts.md](../api/quality-contracts.md), secciones 3–7; [quality.openapi.json](../api/quality.openapi.json) |
| Tabla de estados PENDING_REVIEW, PUBLISHED, REJECTED y RETIRED | [quality-publication.md](../architecture/quality-publication.md), sección 2; MaterialStatus en ambos OpenAPI |
| Permisos STUDENT, MODERATOR y ADMIN | quality-contracts.md, sección 2; x-allowed-roles por operación |
| Errores HTTP 401, 403, 404 y 409 | quality-contracts.md, sección 8; respuestas de OpenAPI |
| Idempotencia de moderación | quality-publication.md, secciones 4–5; Idempotency-Key, operationId y recibos |
| Consulta y descarga autorizada de pendientes | quality-contracts.md, sección 4; [contrato interno de Material](../api/material-quality-internal.openapi.json) |
| Aplicación de cambios en Material y Search | quality-publication.md, secciones 1, 4, 6 y 7 |
| Exclusión de materiales ocultos en búsquedas y descargas públicas | quality-publication.md, sección 7, incluyendo el alcance temporal de la garantía |
| Contratos disponibles y acordados con Web y Mobile | Registros de las secciones 4–6 de este documento |
| Seguimiento informativo de implementación posterior | Sección 7; completar sus ocho filas no es una condición de cierre de esta tarea |
| Auditoría de consultas administrativas y archivos privados | quality-publication.md, sección 6.5: actor, recurso, fecha, resultado y servicio responsable |
| Adopción de S3-05 y dependencia de autorización interna | quality-publication.md, secciones 6.1–6.4; registro de dependencias de la sección 6 de este documento |

## 2. Comprobaciones documentales de este PR

Desde la raíz del repositorio:

```powershell
node scripts/validate-quality-contracts.cjs
git diff --check
```

El script comprueba referencias locales, rutas y parámetros, seguridad
declarada, roles, estados canónicos, claves de idempotencia, endpoints
esenciales y enlaces Markdown locales.

Usa únicamente Node. No levanta servicios, no accede a PostgreSQL y no
sustituye un validador completo de OpenAPI ni pruebas de autorización real.

Los dos archivos OpenAPI y sus ejemplos fueron comprobados durante la
preparación del paquete original. Si se modifican sus esquemas o ejemplos,
deben volver a validarse.

El resultado del script acredita únicamente las comprobaciones documentales
que realiza. No acredita aprobación de las áreas ni ejecución de endpoints.

Antes de solicitar la aprobación final:

- [ ] Ejecutar el validador sobre la versión final de los documentos.
- [ ] Comprobar el diff con `git diff --check`.
- [ ] Comprobar el contenido preparado para commit con `git diff --cached --check`.
- [ ] Revisar ambos OpenAPI en el visor o validador del equipo.
- [ ] Verificar los enlaces del README y de este documento.
- [ ] Confirmar que Markdown y OpenAPI describen las mismas reglas.

## 3. Escenarios exigidos para la implementación posterior

Esta matriz define resultados esperados. Su presencia no significa que los
escenarios hayan sido implementados o ejecutados.

| ID | Escenario | Resultado esperado |
| --- | --- | --- |
| AUTH-01 | Token ausente, mock/alg:none, inválido, expirado o revocado en ruta privada | 401; WWW-Authenticate; sin datos ni escritura |
| AUTH-02 | Token válido STUDENT consulta pendientes o descarga privada | 403; sin archivo ni metadatos |
| AUTH-03 | MODERATOR/ADMIN activo consulta snapshot privado | 200 con revision; sin storageKey |
| AUTH-04 | Cuenta inactiva o headers x-role/x-user-id falsificados | Sin elevación de privilegios; cuenta inactiva 403 |
| AUTH-05 | Acceso directo al servicio saltando Gateway | Mismas comprobaciones de autorización |
| AUTH-06 | Credencial interna inválida, identidad de servicio no verificable o permiso insuficiente | 401 por credencial inválida; 403 por permiso insuficiente, conforme al perfil interno que se acuerde bajo S3-05 |
| AUTH-07 | Actor decide sobre material propio, incluido ADMIN | 403 |
| AUTH-08 | No puede verificarse una condición de autorización que depende de Auth | Error controlado; no se concede acceso por defecto |
| MOD-01 | Aprobar PENDING_REVIEW con revision vigente | 202; luego APPLIED/PUBLISHED, verified=false |
| MOD-02 | Rechazar pendiente con motivo | APPLIED/REJECTED; sin visibilidad pública |
| MOD-03 | Retirar publicado | APPLIED/RETIRED, verified=false |
| MOD-04 | Reabrir rechazado/retirado por moderador autorizado | APPLIED/PENDING_REVIEW; no publica automáticamente |
| MOD-05 | VERIFY publicado no verificado; REVOKE_VERIFICATION verificado | Conserva PUBLISHED; cambia verified según acción |
| MOD-06 | Transición inválida o falta motivo obligatorio | 409 o 400 respectivamente; sin efectos |
| MOD-07 | Contenido, enlace o estado cambia desde snapshot | 409 STALE_REVISION o operación FAILED por conflicto posterior a aceptación |
| MOD-08 | Dos decisiones distintas sobre misma revision | Como máximo una aplica; la otra presenta conflicto |
| IDEM-01 | Misma clave y payload, incluso después de perder respuesta | Una operación y efectos no duplicados; replay devuelve la misma operación |
| IDEM-02 | Misma clave con otro material, motivo o action | 409 IDEMPOTENCY_CONFLICT |
| IDEM-03 | Dos workers entregan simultáneamente el mismo operationId | Un recibo y un efecto; mismo resultado |
| IDEM-04 | Material confirma y Quality pierde la respuesta | Reintento recupera recibo; no duplica ni revierte |
| IDEM-05 | GET del recibo devuelve 404 mientras el primer PUT sigue en curso | No declarar rollback; reintentar el mismo PUT |
| IDEM-06 | Material caído tras aceptación en Quality | Operación pendiente durable; se recupera después; UI no anuncia publicación |
| IDEM-07 | Actor pierde el rol después de aceptación durable | Según propuesta A5: completar la operación aceptada; impedir nuevas decisiones y consultas privadas sin permiso actual |
| IDEM-08 | Actor pierde el rol antes de que se autorice y acepte la operación | Rechazar la nueva operación; una pantalla abierta no constituye autorización |
| VIS-01 | Cada estado no público por listado, detalle y descarga | Excluido del listado; detalle y descarga 404 |
| VIS-02 | Versión de otro material o inexistente | 404 incluso en descarga privada |
| VIS-03 | Nueva búsqueda cuya comprobación de visibilidad ocurre después del commit del retiro | No incluir el material retirado |
| VIS-04 | LINK pendiente, rechazado o retirado | No exponer externalLink por rutas públicas |
| VIS-05 | Descarga privada | attachment, MIME y length correctos; no-store; sin URL pública ni storageKey |
| VIS-06 | Material publicado con varias versiones | Históricas accesibles según contrato; revisión cubre el agregado |
| VIS-07 | Favorito de material posteriormente oculto | available=false sin metadatos ni archivo; no revelar el estado privado |
| VIS-08 | Dependencia falla al comprobar visibilidad | 502/503; no servir una copia que omita la comprobación ni asumir visibilidad |
| RAT-01 | score 1 y 5; 0, 6, 1.5 y cadena "5" | Extremos aceptados; otros 400; BD conserva CHECK |
| RAT-02 | Dos PUT propios y mismo PUT repetido | Una nota vigente; repetición idéntica no cambia updatedAt |
| RAT-03 | Calificar material propio | 403 |
| RAT-04 | Eliminar nota propia ausente o de material oculto | 204; no revela información privada |
| RAT-05 | Resumen sin calificaciones | count=0 y average=null; no sustituir null por 0.0 en el DTO |
| RAT-06 | Resumen con calificaciones | count positivo y average entre 1 y 5 |
| RAT-07 | Republicar material con calificaciones previas | Según propuesta A4: conservar las notas y volver a incluirlas en el resumen |
| REP-01 | OTHER sin detalles o motivo desconocido | 400 |
| REP-02 | Dos reportes abiertos del mismo usuario/material, distintas claves | Uno aceptado; otro 409 incluso bajo concurrencia |
| REP-03 | Repetir creación o PATCH con misma clave y payload | Mismo recurso o snapshot; sin reabrir ni duplicar |
| REP-04 | Usuario consulta reporte ajeno | 404; moderador autorizado sí accede |
| REP-05 | Reportero o autor del material intenta resolver | 403 |
| REP-06 | Dos PATCH con expectedUpdatedAt igual | Uno aplica; otro 409; repetir la clave original devuelve su snapshot |
| REP-07 | Resolver reporte | No altera Material; retiro requiere decisión separada |
| FAV-01 | Repetir PUT/DELETE propio | Sin duplicados; DELETE devuelve 204 si está autenticado y el UUID es válido |
| PAGE-01 | Página fuera de rango o sin registros | 200, items=[], total correcto |
| PAGE-02 | Mismo createdAt entre registros | Desempate id DESC, resultado reproducible sin cambios de datos |
| PAGE-03 | Parámetro desconocido, vacío, repetido u offset excesivo | 400 |
| MIG-01 | Datos existentes con WITHDRAWN | Adaptación a RETIRED conserva filas y visibilidad oculta |
| MIG-02 | migrate deploy repetido | No pierde datos ni reaplica efectos |
| COMP-01 | Cliente consume contrato nuevo de Quality | Usa RETIRED; no serializa WITHDRAWN como estado del contrato nuevo |
| COMP-02 | Adaptador temporal consume WITHDRAWN del Material legado | Compatibilidad delimitada al servicio legado y normalización documentada; no crea un segundo estado canónico |
| AUD-01 | Consulta administrativa de pendientes | Quality registra actor verificado, fecha, filtros/paginación, resultado y correlación; Material registra su atención interna cuando la solicitud llega a él |
| AUD-02 | Lectura de snapshot privado | Auditoría con materialId, revision entregada cuando corresponda, actor, fecha, resultado y servicio responsable |
| AUD-03 | Descarga privada autorizada | Se identifica material/versión y se distingue autorización de resultado final de transferencia |
| AUD-04 | Acceso denegado o identidad inválida | Se registra la denegación; no se atribuye identidad verificada a datos procedentes de una credencial inválida |
| AUD-05 | Transferencia interrumpida después de enviar cabeceras | Se registra ERROR o ABORTED aunque el estado HTTP emitido haya sido 200 |
| AUD-06 | Inspección de registros de auditoría | No contienen tokens, claves, storageKey, URLs firmadas ni contenido de archivos; son correlacionables entre servicios |

Los escenarios que dependan de una decisión todavía pendiente deberán
actualizarse si el equipo acuerda una política diferente.

## 4. Registro de aceptación por área

Completar con responsables reales, fecha, enlace permanente de aprobación y
versión o commit del contrato revisado.

No marcar como aprobado únicamente porque:

- El JSON es válido.
- Pasan pruebas unitarias de modelos.
- Se implementó un cliente.
- Un comentario llama "oficial" al contrato.
- Un participante pudo abrir la documentación.

| Área | Responsable / usuario | Fecha de aprobación | Evidencia de aprobación | Versión o commit revisado | Estado |
| --- | --- | --- | --- | --- | --- |
| Backend / Material | Pendiente | — | — | — | Pendiente |
| Backend / Quality | Pendiente | — | — | — | Pendiente |
| Auth / Gateway | Pendiente | — | — | — | Pendiente |
| Search | Pendiente | — | — | — | Pendiente |
| Web | Pendiente | — | — | — | Pendiente |
| Mobile | Pendiente | — | — | — | Pendiente |

Una persona puede representar varias áreas si el equipo reconoce ese alcance.
No se exige una persona distinta por fila.

La evidencia debe identificar qué se aprueba. Un comentario puede cubrir
varias decisiones o áreas si lo declara explícitamente.

Cuando una modificación posterior cambie una regla aprobada, registrar la
confirmación de esa modificación. Los cambios de formato o el añadido de
enlaces de aceptación no deben confundirse con cambios de comportamiento.

### 4.1. Evidencia técnica complementaria de Mobile

Se recibió un comentario que informa implementación de modelos Dart,
19 pruebas unitarias aprobadas y análisis estático sin incidencias.

Ese comentario constituye evidencia declarada de consumo del contrato.
No equivale por sí solo a aprobación de todas las políticas de publicación,
autorización y moderación.

| Evidencia | Enlace permanente | Versión del contrato utilizada | Alcance |
| --- | --- | --- | --- |
| Comentario de implementación de modelos Mobile | Pendiente de registrar | Pendiente de confirmar | Evidencia técnica complementaria; aceptación formal pendiente |

Antes de cerrar la aceptación de Mobile:

- [ ] Confirmar que RatingSummary conserva average=null cuando count=0.
- [ ] Confirmar que average está entre 1 y 5 cuando existen calificaciones.
- [ ] Delimitar cualquier compatibilidad con WITHDRAWN al Material legado.
- [ ] Confirmar que el contrato nuevo de Quality utiliza RETIRED.
- [ ] Confirmar interpretación de PENDING_APPLICATION, APPLIED y FAILED.
- [ ] Confirmar que 202 no se interpreta como publicación completada.
- [ ] Registrar aprobación explícita del representante de Mobile sobre la versión revisada.

## 5. Decisiones que deben quedar acordadas

Los textos de esta tabla son propuestas concretas para revisión.
La columna de resolución definitiva debe completarse con el acuerdo real.

| ID | Tema | Propuesta sometida a acuerdo | Áreas participantes | Resolución definitiva | Estado | Evidencia |
| --- | --- | --- | --- | --- | --- | --- |
| A1 | RETIRED y adaptación de WITHDRAWN | RETIRED es el nombre definitivo. Adaptar el enum actual mediante una nueva migración que conserve datos, actualizar referencias y coordinar el despliegue. No aceptar ambos nombres como estados públicos del contrato nuevo. | Backend / Material; Web y Mobile para compatibilidad | Pendiente de confirmar | Pendiente | — |
| A2 | Autorrevisión y autoría | Ningún usuario, incluido ADMIN, puede emitir decisiones de moderación sobre material propio. Se prohíbe autocalificación y tramitar reportes propios o relativos a material propio. | Backend; Web; Mobile | Pendiente de confirmar | Pendiente | — |
| A3 | Versiones históricas | La publicación es a nivel de material e incluye sus versiones descargables. La revisión abarca el conjunto. No se aprueba si una versión histórica no puede exponerse. Los cambios relevantes vuelven a revisión según las reglas del contrato. | Backend / Material y Quality; Web; Mobile | Pendiente de confirmar | Pendiente | — |
| A4 | Calificaciones al republicar | Las calificaciones pertenecen al material, se conservan al ocultarlo y reaparecen al republicar. No representan exclusivamente su nueva versión. | Backend / Quality; Web; Mobile | Pendiente de confirmar | Pendiente | — |
| A5 | Pérdida del rol del moderador | Una decisión autorizada y aceptada duraderamente continúa procesándose aunque el actor pierda el rol después. La pérdida del rol impide nuevas decisiones y accesos privados. No se considera aceptada una petición solo por estar abierta en la interfaz. | Backend / Quality, Material y Auth; Web; Mobile | Pendiente de confirmar | Pendiente | — |
| A6 | Autenticación y comunicación autorizada | Adoptar S3-05 / #445 para identidad, propagación y semántica de autorización. Registrar como dependencia pendiente el perfil específico Quality → Material; no atribuir a S3-05 algoritmos, scopes o credenciales internas que no define. | Backend / Auth, Gateway, Quality y Material; Web y Mobile para consumo | Referencia común consensuada; adopción y dependencia de Quality pendientes de confirmar | Pendiente | S3-05 / #445; añadir evidencia de aceptación de este alcance |
| A7 | Auditoría de accesos administrativos | Registrar consultas de pendientes, snapshots y descargas privadas con actor verificado, material/versión cuando corresponda, fecha UTC, resultado y servicio responsable; correlacionar Quality y Material y distinguir autorización de transferencia. | Backend / Quality y Material | Pendiente de confirmar | Pendiente | — |

Para A1, ambos documentos proponen una nueva migración que conserve
los datos y un despliegue coordinado. Esta estrategia queda pendiente
de confirmación; su ejecución pertenece a la implementación posterior.

Para A5, si se acuerda cancelar operaciones pendientes ante pérdida de rol,
debe definirse cómo se cancela una operación sin contradecir un cambio ya
confirmado o en curso en Material. No basta con cambiar una frase ni marcar
FAILED ante un resultado incierto.

### 5.1. Otros acuerdos del contrato completo

Además de A1–A7, confirmar el alcance restante:

- [ ] Material conserva la autoridad sobre status y verified.
- [ ] Quality conserva decisiones y evidencia; no mantiene un estado público autoritativo alternativo.
- [ ] REOPEN corresponde a moderadores; el reenvío especializado del autor queda para otra tarea de Material.
- [ ] Se acepta el flujo 202 y operación consultable.
- [ ] Se aceptan idempotencia, control de revisión y recuperación de resultados inciertos.
- [ ] Aprobar y verificar son operaciones distintas.
- [ ] Los favoritos de materiales ocultos conservan únicamente la referencia propia permitida.
- [ ] Search obtiene candidatos visibles mediante el contrato público de Material.
- [ ] Se acepta el alcance temporal de visibilidad descrito en quality-publication.md.
- [ ] Web y Mobile tienen acceso al contrato antes de integrar endpoints reales.

Una aprobación del contrato completo puede cubrir estos puntos, siempre que
la versión revisada y el alcance de la aprobación queden identificados.

## 6. Referencia de autorización y dependencias

El contrato común de identidad y autorización se encuentra consensuado en
[S3-05 / #445](https://github.com/cchelooo/ApuntesUCT/issues/445),
documentado en [contrato-autorizacion-entre-servicios.md](../api/contrato-autorizacion-entre-servicios.md).

Quality adopta esa referencia. No redefine unilateralmente los claims,
el transporte de credenciales ni la semántica común de autorización.

| Aspecto | Referencia o definición | Situación |
| --- | --- | --- |
| Identidad y propagación de usuario | S3-05, secciones 5.1–5.3: Bearer, propagación del token, identidad verificada y sub correspondiente a user.id | Contrato común consensuado |
| Roles y permisos | S3-05, secciones 4.5 y 5.4; restricciones de recurso y autoría del contrato Quality | Base común consensuada; políticas específicas sujetas a aceptación de Quality |
| Errores de autenticación y autorización | S3-05, sección 5.5: 401 y 403, más errores de dependencia según operación | Adoptar manteniendo compatibilidad de respuestas |
| Login real y emisión de JWT | #441, referenciada por S3-05 | Dependencia de implementación; este registro no acredita su estado de ejecución |
| Autorización Quality → Material | S3-05, secciones 2, 5.6 y 6: requiere mecanismo interno explícitamente documentado | Perfil específico pendiente de definición y acuerdo |
| Actor de operaciones ya aceptadas | Política A5 y quality-publication.md, sección 6.4 | Pendiente de confirmación como política de Quality |
| Auditoría de accesos administrativos | quality-publication.md, sección 6.5 | Propuesta documentada; pendiente de aceptación A7 |

El perfil interno deberá definir la identidad verificable del servicio,
los permisos por operación y la vinculación del actor y de operationId.
Su implementación será necesaria antes de habilitar las rutas internas.

La dependencia se registra como pendiente. No se exige implementar el
perfil, endpoints ni migraciones para cerrar esta tarea documental.

No se consideran aprobados por S3-05 los detalles de la propuesta previa
de aserciones de servicio: RS256 obligatorio, vigencia de 60 segundos o
nombres concretos de scopes.

## 7. Tareas de implementación pendientes

Buscar y enlazar tareas existentes antes de crear otras.

Los identificadores IMP-01, IMP-02, etc. son referencias locales de esta
tabla; no son números de issues.

| ID local | Trabajo pendiente | Alcance mínimo | Área responsable | Issue o tarea real | Estado |
| --- | --- | --- | --- | --- | --- |
| IMP-01 | Adaptar WITHDRAWN a RETIRED | Migración conservando datos, actualización de referencias, pruebas y despliegue coordinado | Backend / Material | Pendiente de vincular | Pendiente |
| IMP-02 | Autenticación y autorización de usuarios | JWT real, roles, actividad y revocación conforme a A6 | Backend / Auth y servicios consumidores | Pendiente de vincular | Pendiente |
| IMP-03 | Comunicación autorizada Quality → Material | Credencial de servicio, permisos, verificación del actor y protección de rutas internas | Backend / Quality y Material | Pendiente de vincular | Pendiente |
| IMP-04 | Consulta y descarga privada | Listado de pendientes, snapshot con revision y acceso autorizado a versiones | Backend / Quality y Material | Pendiente de vincular | Pendiente |
| IMP-05 | Aplicación de decisiones | Moderación, verificación, retiro, revision, idempotencia, recibos y recuperación | Backend / Quality y Material | Pendiente de vincular | Pendiente |
| IMP-06 | Calificaciones, reportes y favoritos | Endpoints, validaciones, autorización y persistencia conforme al contrato | Backend / Quality | Pendiente de vincular | Pendiente |
| IMP-07 | Gateway y visibilidad pública | Enrutamiento de Quality, exclusión de rutas internas y comprobaciones de visibilidad en Material/Search | Backend / Gateway, Material y Search | Pendiente de vincular | Pendiente |
| IMP-08 | Integración de clientes | Consumo de endpoints reales, estados de operación, errores y tratamiento de materiales ocultos | Web y Mobile | Pendiente de vincular | Pendiente |

Una tarea real puede cubrir varias filas. Si una tarea ya fue implementada,
registrar su enlace y evidencia en lugar de mantenerla como pendiente.

No es necesario completar estas implementaciones para cerrar la tarea de
contratos.

Esta tabla es seguimiento informativo de implementación posterior.
No es necesario completar, asignar o vincular sus ocho filas como
condición de cierre de #444, conforme a la aclaración del revisor.

La referencia a S3-05 y la dependencia pendiente del perfil interno
Quality → Material sí quedan expresamente registradas en la sección 6.

## 8. Procedimiento para pasar de PROPUESTO a ACORDADO

1. Confirmar las decisiones de estados y publicación A1–A5.
2. Confirmar la adopción de S3-05 y el registro de la dependencia interna A6.
3. Confirmar la auditoría de accesos administrativos A7.
4. Incorporar las resoluciones en los documentos y mantener coherencia
   con ambos OpenAPI.
5. Registrar la evidencia de aprobación de las áreas correspondientes,
   identificando la versión o commit revisado.
6. Confirmar que Web y Mobile tienen acceso a los contratos versionados.
7. Actualizar el estado a ACORDADO y registrar fecha y versión.
8. Ajustar, si corresponde, las comprobaciones del validador relativas
   al estado documental, conservando sus controles técnicos.
9. Ejecutar la validación documental y revisar el diff de la versión final.
10. Solicitar la revisión final del PR.

No se requiere implementar endpoints ni migraciones, ni completar la
tabla de ocho tareas de implementación, para cerrar esta tarea.

Los checks del PR acreditan sus comprobaciones automatizadas; no
sustituyen la confirmación de las políticas ni la evidencia de acuerdo.

## 9. Registro de cierre

Completar únicamente cuando exista evidencia.

| Elemento | Registro |
| --- | --- |
| Versión final del contrato | Pendiente |
| Commit o referencia versionada del contrato revisado | Pendiente |
| Fecha de acuerdo | Pendiente |
| Aprobación de Backend | Pendiente |
| Aprobación de Web | Pendiente |
| Aprobación de Mobile | Pendiente |
| Decisiones A1–A7 confirmadas | Pendiente |
| Referencia a S3-05 y dependencia interna registradas | S3-05 / #445 referenciado; perfil Quality → Material pendiente de acuerdo |
| Seguimiento de implementación | Informativo; completar sus ocho filas no condiciona el cierre |
| Validación documental de la versión final | Pendiente |
| Revisión final del PR | Pendiente |

Una vez completado el acuerdo, la declaración documental será:

> Estado: ACORDADO. Los contratos y políticas han sido aprobados por las
> áreas registradas. La implementación funcional continúa en las tareas
> vinculadas; este acuerdo no acredita endpoints desplegados ni pruebas
> funcionales completadas.

El contrato interno se comparte con Backend. Web y Mobile consumen el
contrato externo de Quality y no deben llamar directamente a las rutas
internas de Material.