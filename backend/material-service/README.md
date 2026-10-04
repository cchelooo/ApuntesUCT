# Material Service

Base ejecutable NestJS del microservicio de materiales académicos (#216).
Requiere Node.js 22 y npm. En esta etapa no necesita PostgreSQL ni MinIO.

## Instalación y ejecución

Desde la raíz del repositorio:

```bash
cd backend
npm ci
cp material-service/.env.example material-service/.env # solo si no existe
npm run start:dev --workspace=material-service
```

`PORT` es opcional y vale `3003` por defecto. El archivo `.env` se carga desde
el directorio del servicio al usar los scripts del workspace. Las variables del
proceso tienen prioridad sobre el archivo.

Para compilar y ejecutar en producción, desde `backend/`:

```bash
npm run build --workspace=material-service
npm run start:prod --workspace=material-service
```

La compilación genera `dist/main.js`. También se puede ejecutar `npm run start
--workspace=material-service` para compilar y levantar sin watch.

## Endpoints

| Endpoint | Propósito |
| --- | --- |
| `GET http://localhost:3003/api/v1/health` | Estado del proceso |
| `GET http://localhost:3003/api/docs` | Swagger UI |
| `GET http://localhost:3003/api/docs-json` | Especificación OpenAPI |

El healthcheck responde `200` con `status: "ok"`, `service: "material-service"`
y `timestamp` en formato ISO. No comprueba dependencias externas.
Las rutas de la API usan el prefijo `api/v1`; Swagger queda en `api/docs`.
CORS está habilitado siguiendo los demás servicios del backend.

## Estructura

- `src/presentation`: controladores HTTP y módulos de entrada.
- `src/application`: servicios de aplicación, incluido el healthcheck.
- `src/domain`: espacio para las futuras entidades y reglas de materiales.
- `src/infrastructure`: configuración mediante variables de entorno.

La persistencia, el almacenamiento de archivos y las operaciones de materiales
quedan para las tareas siguientes.

## Verificación

Desde `backend/`:

```bash
npm run lint:material
npm test --workspace=material-service -- --runInBand
npm run test:e2e --workspace=material-service -- --runInBand
curl http://localhost:3003/api/v1/health
```

Las pruebas HTTP verifican el prefijo, el healthcheck, Swagger UI y la ruta
documentada en OpenAPI. No requieren base de datos.

El servicio participa en los comandos globales `build`, `lint`, `test`,
`test:ci` y `test:cov` del backend mediante npm workspaces.
