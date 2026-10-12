# Validación del proxy del Gateway para multipart y binarios — 12 de octubre de 2026

Tarea [#237](https://github.com/cchelooo/ApuntesUCT/issues/237), dentro de la semana 2
del Sprint 2 (padre [#230](https://github.com/cchelooo/ApuntesUCT/issues/230)). Verifica
que el API Gateway permita **subir** `multipart/form-data` hacia Material Service y
**descargar** archivos binarios sin alterar el cuerpo, dejando a Web/Mobile con un único
origen: `http://localhost:3000`.

## Criterios de aceptación y evidencia

| Criterio | Evidencia | Resultado |
| --- | --- | --- |
| Una subida funciona pasando por el puerto `3000` | `api-gateway/test/material-contract.integration.cjs`: POST multipart a `http://127.0.0.1:3000/api/v1/materials` con Material escuchando en `3003` | OK |
| Una descarga funciona pasando por el puerto `3000` | Mismo archivo: GET binario a `http://127.0.0.1:3000/api/v1/materials/:id/download` | OK |
| Web/Mobile no necesitan acceder a `3003` | El cliente solo conoce `3000`; el Gateway resuelve `MATERIAL_SERVICE_URL` a su puerto reservado `3003` (`proxy.module.ts`, cubierto por `proxy.module.spec.ts`) | OK |
| Los headers necesarios se conservan | `Content-Type`, `Content-Disposition` (incl. `filename*` UTF-8) y `Content-Length` verificados extremo a extremo | OK |

## Topología reproducida

```
Web/Mobile ──▶ Gateway :3000 ──▶ Material Service :3003 ──▶ MinIO
                     (multipart y binario sin transformar)
```

La prueba de integración levanta el Gateway en `3000` y el Material Service real en
`3003` (su puerto reservado), sin sobrescribir `MATERIAL_SERVICE_URL`. Se usan los
controladores, validadores y casos de uso reales con persistencia (Prisma) y
almacenamiento (MinIO) **simulados**, porque no requieren una base ni un MinIO reales.

## Evidencia automatizada

- **Gateway → contrato real de Material** (`npm run test:integration --workspace=api-gateway`):
  **16 aprobadas**. Además de la subida multipart (metadatos Unicode, cinco formatos,
  MIME detectado, límite de 15 MB, `400`/`413`/`415`/`502`), cubre:
  - descarga binaria íntegra por el Gateway (`200`, bytes idénticos, `Content-Type`,
    `Content-Disposition` con `filename*` y `Content-Length` conservados);
  - `404` del material propagado con su formato de error;
  - `400` por `id` no UUID propagado.
- **Gateway HTTP** (`npm run test:e2e --workspace=api-gateway`): **43 aprobadas**,
  incluida la conservación de `Content-Disposition` con `filename*` UTF-8 a través del
  proxy y el paso de un cuerpo con bytes no UTF-8.
- **Material HTTP** (`npm run test:e2e --workspace=material-service`): descarga con
  nombres especiales (tildes, `ñ`, espacios, comillas) y protección de inyección de
  cabeceras.
- **Gateway unitario** (`npm run test`): verifica que Material se enruta por defecto a
  `http://127.0.0.1:3003` con `changeOrigin` y timeout, y que las rutas
  `materials`/`materials/*path` capturan todos los métodos.

## Reproducción

Desde `backend`:

```bash
npm run build --workspace=material-service
npm run build --workspace=api-gateway
npm run test:integration --workspace=api-gateway
npm run test:e2e --workspace=api-gateway
```

## Límites

- La validación usa persistencia y almacenamiento simulados: comprueba el transporte del
  proxy (cabeceras y bytes), no la escritura/lectura real en PostgreSQL o MinIO. El flujo
  contra MinIO real se comprobó por separado al integrar la descarga (#236).
- Los puertos `3000`/`3003` están fijos en la prueba; deben estar libres al ejecutarla.
- No se modificó `service-proxy.ts`: la validación confirma que el comportamiento actual
  (streaming sin `buffer` para cuerpos no analizados) ya satisface los criterios.
