# ValidaciÃ³n del proxy del Gateway para multipart y binarios â€” 12 de octubre de 2026

Tarea [#237](https://github.com/cchelooo/ApuntesUCT/issues/237), dentro de la semana 2
del Sprint 2 (padre [#230](https://github.com/cchelooo/ApuntesUCT/issues/230)). Verifica
que el API Gateway permita **subir** `multipart/form-data` hacia Material Service y
**descargar** archivos binarios sin alterar el cuerpo, dejando a Web/Mobile con un Ãºnico
origen: `http://localhost:3000`.

## Criterios de aceptaciÃ³n y evidencia

| Criterio | Evidencia | Resultado |
| --- | --- | --- |
| Una subida funciona pasando por el puerto `3000` | `api-gateway/test/material-contract.integration.cjs`: POST multipart a `http://127.0.0.1:3000/api/v1/materials` con Material escuchando en `3003` | OK |
| Una descarga funciona pasando por el puerto `3000` | Mismo archivo: GET binario a `http://127.0.0.1:3000/api/v1/materials/:id/download` | OK |
| Web/Mobile no necesitan acceder a `3003` | El cliente solo conoce `3000`; el Gateway resuelve `MATERIAL_SERVICE_URL` a su puerto reservado `3003` (`proxy.module.ts`, cubierto por `proxy.module.spec.ts`) | OK |
| Los headers necesarios se conservan | `Content-Type`, `Content-Disposition` (incl. `filename*` UTF-8) y `Content-Length` verificados extremo a extremo | OK |

## TopologÃ­a reproducida

```
Web/Mobile â”€â”€â–¶ Gateway :3000 â”€â”€â–¶ Material Service :3003 â”€â”€â–¶ MinIO
                     (multipart y binario sin transformar)
```

La prueba de integraciÃ³n levanta el Gateway en `3000` y el Material Service real en
`3003` (su puerto reservado), sin sobrescribir `MATERIAL_SERVICE_URL`. Se usan los
controladores, validadores y casos de uso reales con persistencia (Prisma) y
almacenamiento (MinIO) **simulados**, porque no requieren una base ni un MinIO reales.

## Evidencia automatizada

- **Gateway â†’ contrato real de Material** (`npm run test:integration --workspace=api-gateway`):
  **16 aprobadas**. AdemÃ¡s de la subida multipart (metadatos Unicode, cinco formatos,
  MIME detectado, lÃ­mite de 15 MB, `400`/`413`/`415`/`502`), cubre:
  - descarga binaria Ã­ntegra por el Gateway (`200`, bytes idÃ©nticos, `Content-Type`,
    `Content-Disposition` con `filename*` y `Content-Length` conservados);
  - `404` del material propagado con su formato de error;
  - `400` por `id` no UUID propagado.
- **Gateway HTTP** (`npm run test:e2e --workspace=api-gateway`): **43 aprobadas**,
  incluida la conservaciÃ³n de `Content-Disposition` con `filename*` UTF-8 a travÃ©s del
  proxy y el paso de un cuerpo con bytes no UTF-8.
- **Material HTTP** (`npm run test:e2e --workspace=material-service`): descarga con
  nombres especiales (tildes, `Ã±`, espacios, comillas) y protecciÃ³n de inyecciÃ³n de
  cabeceras.
- **Gateway unitario** (`npm run test`): verifica que Material se enruta por defecto a
  `http://127.0.0.1:3003` con `changeOrigin` y timeout, y que las rutas
  `materials`/`materials/*path` capturan todos los mÃ©todos.

## ReproducciÃ³n

Desde `backend`:

```bash
npm run build --workspace=material-service
npm run build --workspace=api-gateway
npm run test:integration --workspace=api-gateway
npm run test:e2e --workspace=api-gateway
```

## LÃ­mites

- La validaciÃ³n usa persistencia y almacenamiento simulados: comprueba el transporte del
  proxy (cabeceras y bytes), no la escritura/lectura real en PostgreSQL o MinIO. El flujo
  contra MinIO real se comprobÃ³ por separado al integrar la descarga (#236).
- Los puertos `3000`/`3003` estÃ¡n fijos en la prueba; deben estar libres al ejecutarla.
- No se modificÃ³ `service-proxy.ts`: la validaciÃ³n confirma que el comportamiento actual
  (streaming sin `buffer` para cuerpos no analizados) ya satisface los criterios.

