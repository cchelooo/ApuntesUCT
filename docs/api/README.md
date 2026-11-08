# API pública para INT2 e INT4

La entrada HTTP de Web, Mobile y Postman es el **Gateway** (`http://localhost:3000`).

| Archivo | Uso |
| --- | --- |
| `apuntesuct.openapi.json` | OpenAPI consolidado, generado desde los controladores de los cinco servicios; rutas públicas con servidor Gateway |
| `apuntesuct.postman_collection.json` | Peticiones de Auth, Catalog, Material y Search mediante Gateway |
| `apuntesuct.postman_environment.json` | Variables para el entorno local |
| [integracion-material-search.md](integracion-material-search.md) | Contratos, ejemplos, autenticación temporal, errores y arranque para INT2/INT4 |

## Importar y ejecutar

Importar colección y environment en Postman y activar **ApuntesUCT local**.
En Insomnia, importar como Postman v2.1. Cambiar `gatewayUrl` por el host del Gateway,
sin añadir `/api/v1`: las peticiones ya incluyen ese prefijo.

1. Levantar los servicios según la guía enlazada.
2. Obtener IDs reales mediante los selectores de Catalog. Reemplazar `universityId`,
   `careerId`, `subjectId` y `professorId`; los UUID iniciales son ilustrativos.
3. Ejecutar listado de Material: si hay resultados, su prueba guarda el primer
   `materialId` en la colección. También puede establecerse manualmente con un ID publicado.
4. Ejecutar detalle: guarda `versionId` de la versión actual, o lo vacía si no hay archivo.
5. Para descargar una versión anterior, copiar su ID desde `versions` a `versionId`
   y activar ese parámetro en la petición de descarga. Usar **Send and Download**.
6. Para subir, seleccionar un archivo local en `Body → form-data → file` y completar
   los metadatos. Postman establece el boundary: no añadir Content-Type manualmente.
   Para `LINK`, desactivar `file`, elegir `type=LINK` y activar `externalLink`.
7. Crear versión usa el mismo `materialId` y un nuevo archivo; requiere que el
   contexto local de autor coincida con el autor del material.

`accessToken`, `materialId` y `versionId` viven solo en la colección, evitando que
un valor vacío del environment oculte los valores capturados. `resourceId` sirve
para las rutas administrativas de Catalog que reciben `{id}`; rellenarlo manualmente.
Los filtros opcionales empiezan desactivados. Activar los académicos en orden
universidad → carrera → asignatura → profesor. Año y tipo son independientes.

El login mock guarda `accessToken`, pero **no autentica las subidas**. Estas requieren
el contexto de autor local descrito en la guía. Las lecturas de Material/Search son públicas.

Las respuestas guardadas son ejemplos ilustrativos del contrato, no capturas de
un entorno real. Las pruebas de descarga verifican respuesta binaria; las demás,
estado esperado y JSON. Una colección con archivos sin seleccionar o IDs sin
configurar no es una suite que pueda ejecutarse automáticamente de principio a fin.

## Regenerar

Desde `backend/`, con las dependencias instaladas:

```bash
npm run build
npm run export:postman
npm run test:api-docs
```

El generador usa `dist`, simula Prisma y almacenamiento y no necesita PostgreSQL,
MinIO ni servicios escuchando. Los tres JSON se versionan juntos. Cambiar los
controladores/DTOs o el generador; no editar las peticiones generadas manualmente.
El OpenAPI consolidado puede importarse en un visor o cliente compatible. Los
Swagger de desarrollo siguen disponibles en `/api/docs` de cada servicio; el
Gateway tiene su índice en `/api/docs` y su Swagger propio en `/api/docs/gateway`.
