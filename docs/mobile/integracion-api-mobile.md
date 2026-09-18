# Soporte de integración con Taller 4 Mobile

**INT2 → INT4 · Sprint 1 · Semana 3**

Este documento prepara y describe los puntos de integración que el API backend de ApuntesUCT expone para la app mobile (Taller 4 Mobile), y responde las dudas planteadas por INT4 en `docs/checklist-integracion-api-mobile.md`.

---

## 1. Punto de entrada único (API Gateway)

Toda la comunicación de la app debe apuntar al **API Gateway** (puerto `3000`), único punto de entrada a los microservicios.

- Base URL: `http://<host>:3000/api/v1`
  - **iOS Simulator / escritorio**: `http://localhost:3000/api/v1`
  - **Android Emulator**: `http://10.0.2.2:3000/api/v1` (mapea el localhost del host)
  - **Dispositivo físico (misma red)**: `http://<IP-LAN-del-host>:3000/api/v1` — el gateway escucha en todas las interfaces
  - La app ya centraliza esto en `mobile/lib/core/config/api_config.dart`, con override por `API_GATEWAY_URL`.

- **CORS**: habilitado en el gateway (`app.enableCors()`), sin restricción de origen.
- **Prefijo global**: el gateway aplica `api/v1` a sus rutas de controladores.

> Nota: en `main` el gateway **aún no redirige** solicitudes hacia los servicios; esa redirección (Gateway → Auth) está en curso en la issue **#91**.

## 2. Documentación (Swagger / OpenAPI)

| Recurso | URL |
|---|---|
| Índice de documentación de servicios | `http://<host>:3000/api/docs` |
| Spec OpenAPI del gateway (JSON) | `http://<host>:3000/api/docs/gateway-json` |
| Swagger Auth Service | `http://localhost:3001/api/docs` · JSON: `/api/docs-json` |
| Swagger Catalog Service | `http://localhost:3002/api/docs` · JSON: `/api/docs-json` |

## 3. Endpoints verificados en main

| Método | Ruta (vía gateway) | Respuesta verificada | Estado |
|---|---|---|---|
| GET | `/api/v1/health` | `200` → `{"status":"ok","service":"API Gateway","timestamp":"..."}` | ✅ Verificado |
| GET | `/api/v1/catalog/filter` (directo a `:3002`) | Lista de asignaturas (DTO con filtros opcionales) | ✅ Compila en `main` (ver nota) |

Comandos de comprobación:

```bash
curl http://localhost:3000/api/v1/health        # gateway
curl http://localhost:3001/api/v1/health        # auth
curl http://localhost:3000/api/docs/gateway-json # spec OpenAPI del gateway
```

> **Nota de compilación (Catalog Service):** `npm run build` de `catalog-service` falla
> con `TS2322` en `src/application/services/catalog.service.ts:77` **solo si el cliente Prisma
> de `node_modules` está desactualizado**. Se resuelve regenerándolo antes de compilar:
> `npm run prisma:generate` en `backend/catalog-service`.

## 4. Respuestas a «Pendiente de confirmar» (checklist de INT4)

| Pregunta | Respuesta INT2 |
|---|---|
| Rutas exactas contra Swagger real | Confirmadas para lo implementado: gateway `/api/v1/health`; catálogo `/api/v1/catalog/filter`. Los endpoints de sesión de auth aún no existen (pendientes de implementación). |
| Esquema de autenticación | **JWT en header `Authorization: Bearer <token>`**, bajo `/api/v1/auth` (`register`, `login`, `refresh`, `logout`). La implementación está pendiente; el esquema es el acordado. |
| Formato de paginación | **`page`/`limit`** (`?page=1&limit=20`) — estándar del proyecto, respuestas paginadas con `items`/`total`. |
| Formato estándar de error | **NestJS por defecto**: `{ statusCode, message, error }` (confirmado; hay `ValidationPipe` global en gateway y servicios). |
| Recuperación de contraseña | Endpoints aún por definir/implementar. |

## 5. Qué puede usar INT4 hoy y qué viene

- **Hoy (main):** healthcheck del gateway y Swagger; healthcheck de auth; catálogo compila en `main` (`GET /api/v1/catalog/filter`).
- **Próximo:** proxy Gateway→Auth (**#91**), endpoints de sesión de auth, servicios Material / Quality / Search.
- **Formato base propuesto a INT4:** apuntar siempre al gateway (`:3000`) y no a los puertos internos de cada servicio (salvo en Swagger para documentación).