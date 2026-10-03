# Issue #271 — dominio Mobile de materiales

Rama: `feature/271-dominio-materiales`. La tarea se divide en dos avances;
el segundo se realizará cuando Marcelo solicite continuar.

## Día 1 — 3 de octubre de 2026

- Añadir `AcademicReference` con un ID lógico obligatorio y nombre opcional.
- Añadir `MaterialStatus`, incluyendo `PENDING_REVIEW` y compatibilidad con
  las etiquetas de los fixtures visuales existentes.
- Evitar interpretar un estado ausente o desconocido como aprobado.
- Cubrir referencias completas, mínimas e inválidas y el parseo de estados.
- Mantener los componentes y modelos de #284 como punto de partida.

Los nuevos tipos aún no se conectan a `MaterialSummary` o `MaterialDetail`;
esa integración pertenece al siguiente avance. No se agregan dependencias
de Dio, Flutter ni widgets a los modelos de dominio.

## Día 2 — pendiente de continuar

- Incorporar estados y referencias académicas a los modelos existentes,
  conservando la compatibilidad de las tarjetas y el detalle.
- Añadir `MaterialVersion` y la respuesta paginada del listado básico.
- Definir operaciones de listar, obtener detalle, subir, descargar y versionar,
  manteniendo la búsqueda en una interfaz separada para Search Service.
- Ampliar fixtures y pruebas de parseo de material completo, mínimo e inválido.
- Revisar compatibilidad con el trabajo de #283 antes de integrar los cambios.

## Contrato de Backend pendiente

Al comenzar este avance, #217, #218 y #219 permanecen abiertas y Material
Service contiene archivos de preparación, sin DTOs ni OpenAPI publicados.
`PENDING_REVIEW` y las referencias lógicas están respaldados por la issue
#271 y los requisitos del proyecto. Los demás códigos de estado y el formato
JSON de las referencias son decisiones internas provisionales, no un contrato
HTTP validado. No se presupone que Backend entregue referencias anidadas.

Cuando INT2 publique el contrato se deberán confirmar los campos obligatorios,
opcionales, códigos de estado, formato de paginación y datos de las versiones.
Esta issue sigue incompleta; no corresponde cerrarla ni declarar su integración
con Backend terminada.

## Validación

Desde `mobile/`:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/features/materials/domain test/features/materials/presentation
```

Resultado del día 1: formato y análisis sin errores; 15 pruebas de materiales
aprobadas, incluyendo 10 pruebas nuevas de esta base del dominio.

Los fixtures de `test/fixtures/materials/domain_foundations.json` son locales
y verifican únicamente esta base del dominio. No son respuestas capturadas
del Gateway ni evidencia de compatibilidad con OpenAPI.
