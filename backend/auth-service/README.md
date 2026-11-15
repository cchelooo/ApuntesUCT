# Auth Service

Microservicio de identidad, autenticación, usuarios y roles del ecosistema ApuntesUCT.

## Stack

- Node.js 22 + TypeScript
- NestJS 11
- Prisma 6 + PostgreSQL 17

## Estructura

Separación por capas según RNF-07 (Presentation / Application / Domain / Infrastructure):

```text
src/
├── presentation/   # Controladores HTTP, DTOs, Swagger
├── application/    # Casos de uso / lógica de negocio
├── domain/         # Entidades y reglas de dominio
└── infrastructure/ # Prisma, configuración, servicios externos
```

## Requisitos

- Node.js 22 (`.nvmrc` en la raíz del repo).
- Instancia de PostgreSQL. Con Docker Compose en la raíz del repo se levanta `db-auth` (puerto `5432`, base `auth_db`).

## Setup

```bash
npm ci --include-workspace-root # incluye herramientas compartidas del backend
cp .env.example .env   # configurar DATABASE_URL según el entorno
npm run prisma:generate
```

## Base de datos

Desde la raíz del repositorio, inicia PostgreSQL:

```bash
docker compose up -d db-auth
```

Desde `backend/auth-service`, valida el esquema y aplica las migraciones:

```bash
npx prisma validate
npm run prisma:migrate   # aplica migraciones y genera nuevas si cambia el modelo
npm run prisma:deploy    # aplica migraciones existentes en despliegues
npx prisma migrate status
npm run prisma:studio    # explorar datos
```

`DATABASE_URL` en `.env` apunta a `auth_db` en `localhost:5432`, con las
credenciales de desarrollo de Docker Compose (ver `.env.example`). Si el servicio
se ejecuta dentro de la red de Compose, el host es `db-auth`.

`PrismaModule` exporta `PrismaService` globalmente para inyectarlo en los
proveedores de NestJS. Al iniciar, el servicio conecta con PostgreSQL; si la
conexión falla, el inicio falla. Al recibir SIGTERM o SIGINT, cierra la conexión.

## Modelo de usuarios (#51)

El modelo `User` de `prisma/schema.prisma` corresponde a `Auth_User` del MER
y se almacena en la tabla `users`. Los campos `id`, `email`, `passwordHash`,
`role` y `createdAt` representan los cinco atributos del MER. Se conservan
`name`, `active`, `updatedAt` y la relación con `RefreshToken` como extensiones
para la gestión de cuentas. `Role` restringe el atributo textual del MER a los
tres valores definidos por el dominio.

La migración inicial `20260907000000_init` crea las tablas con identificadores
de texto. El esquema de la tarea #51 define `users.id` y
`refresh_tokens.user_id` como UUID nativo de PostgreSQL. La migración
`20260914000000_convertir_ids_usuarios_a_uuid` de la tarea #52 aplica esa conversión.

| Campo Prisma | Tipo | Restricciones y propósito |
| --- | --- | --- |
| `id` | `String` / PostgreSQL `uuid` | Clave primaria; Prisma genera un UUID al crear el usuario. |
| `name` | `String` | Nombre obligatorio. |
| `email` | `String` | Correo obligatorio y único. |
| `passwordHash` | `String` | Hash obligatorio de la contraseña; columna `password_hash`. |
| `role` | `Role` | `STUDENT`, `MODERATOR` o `ADMIN`; por defecto `STUDENT`. |
| `active` | `Boolean` | Estado de la cuenta; por defecto `true`. |
| `createdAt` | `DateTime` | Fecha de creación; por defecto la fecha actual; columna `created_at`. |
| `updatedAt` | `DateTime` | Prisma actualiza la fecha al modificar el registro; columna `updated_at`. |
| `refreshTokens` | `RefreshToken[]` | Relación de uno a muchos con los tokens de renovación de sesión. |

Cada `RefreshToken` pertenece a un usuario mediante `userId`. Al eliminar
físicamente un usuario, sus tokens se eliminan en cascada. Cambiar `active` a
`false` conserva el usuario y sus tokens; el flujo de autenticación debe comprobar
ese estado para impedir el acceso de cuentas desactivadas.

Las referencias a usuarios desde Material y Quality son referencias lógicas
(`Soft FK` en el MER). No se crean relaciones Prisma ni claves foráneas entre
las bases de datos de esos microservicios.

La entidad de dominio `src/domain/auth/user.entity.ts` representa los mismos
campos escalares y utiliza los roles de `src/domain/auth/role.enum.ts`.

## Registro institucional (#440)

`POST /api/v1/auth/register` (Auth o Gateway) recibe `name`, `email` y
`password`. Responde `201` con `{ "user": { "id", "name", "email", "role",
"active" } }`, sin sesión ni tokens. El UUID identifica al usuario entre servicios.
El nombre se recorta y admite 3–100 caracteres; el correo se recorta, se convierte
a minúsculas y admite exclusivamente los dominios exactos `uct.cl` y `alu.uct.cl`
(máximo 254 caracteres). La contraseña admite 8–128 caracteres, no puede ser solo
espacios y nunca se recorta ni normaliza. Los datos inválidos devuelven `400`;
un correo duplicado devuelve `409`, incluso ante solicitudes concurrentes.

```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Camila Soto","email":"camila@alu.uct.cl","password":"una clave de ejemplo"}'
```

El registro público asigna siempre `STUDENT`. Campos adicionales como `role`,
`active` o `passwordHash` se descartan. `MODERATOR` y `ADMIN` quedan disponibles
para flujos autorizados posteriores. Prisma selecciona exclusivamente los cinco
campos públicos de la respuesta; nunca retorna la contraseña ni su hash.

Las contraseñas usan scrypt asíncrono (`N=131072`, `r=8`, `p=1`), sal aleatoria
de 16 bytes y clave derivada de 64 bytes. El formato persistido es
`scrypt$N$r$p$saltHex$hashHex`; permite verificar posteriormente sin almacenar
la contraseña. La verificación de credenciales y la emisión JWT corresponden a #441.

La migración `20261109000000_institutional_registration` conserva los UUID y
cuentas, sustituye el rol antiguo `PROFESSOR` por `STUDENT` (sin conceder permisos
de moderación automáticamente), conserva `ADMIN` y añade `MODERATOR`. Normaliza
los correos existentes e impone que se guarden normalizados. Si existen cuentas
que colisionan al normalizar, la transacción completa falla: se deben resolver
esas cuentas explícitamente antes de reintentar, sin eliminar datos automáticamente.
No se reescriben las migraciones históricas. No aplicar sobre producción sin
revisar primero las cuentas con el rol antiguo y posibles colisiones de correo.

**Contrato acordado:** S3-05 / #445 está consensuado en
[el contrato de autorización](https://github.com/cchelooo/ApuntesUCT/blob/main/docs/api/contrato-autorizacion-entre-servicios.md).
El registro público conserva el UUID que usa el claim `sub` del login, no emite
tokens y crea únicamente cuentas `STUDENT` activas.

## Inicio de sesión real (#441)

`POST /api/v1/auth/login` verifica el correo normalizado y la contraseña exacta
contra los usuarios registrados por S3-01. Comprueba el hash scrypt y `active`.
Devuelve `401` con el mismo mensaje para cuenta desconocida, contraseña incorrecta
o usuario inactivo. Los cuerpos inválidos conservan `400`.

Se conserva la ruta pública por Gateway y la respuesta `accessToken`,
`tokenType: "Bearer"`, `expiresIn: 3600`, `user: { id, name, email, role, active }`.
El rol se obtiene de la base de datos. No se devuelven hashes ni refresh tokens.

### Configuración de firma

Configurar en el entorno de Auth (o su `.env` ignorado por Git):

- `JWT_PRIVATE_KEY_PATH`: ruta absoluta a un PEM RSA de al menos 2048 bits,
  montado desde el gestor de secretos fuera del repositorio.
- `JWT_ISSUER`: emisor esperado, por ejemplo `apuntesuct-auth`.
- `JWT_AUDIENCE`: audiencia esperada, por ejemplo `apuntesuct-api`.

El servicio falla al iniciar si falta la configuración o la clave no es válida.
No hay secreto predeterminado ni modo mock. Para desarrollo, generar una clave
fuera del checkout y dar acceso de lectura únicamente al proceso de Auth:

```bash
umask 077
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out /tmp/apuntesuct-auth-private.pem
openssl pkey -in /tmp/apuntesuct-auth-private.pem -pubout -out /tmp/apuntesuct-auth-public.pem
```

El JWT usa RS256 y claims `sub` (UUID persistido), `email`, `role`, `iat`, `exp`,
`iss` y `aud`. `AccessTokenService.verify` restringe el algoritmo a RS256 y
rechaza firmas incorrectas, `alg=none`, expiración, emisor/audiencia incorrectos
y claims de identidad inválidos. Los verificadores de otros servicios deben
recibir solo la clave pública y los mismos valores de emisor/audiencia.

**Alineación con S3-05:** el contrato consensuado de #445 recomienda firma
asimétrica y define `sub = user.id`, `email`, `role`, `exp`, así como verificación
de `iss` y `aud`. Esta implementación usa RS256 y conserva esos campos.
Los permisos de `STUDENT`, `MODERATOR` y `ADMIN` (incluida la herencia de permisos
de moderación en `ADMIN`) se implementan en la tarea de autorización.

El verificador JWT está probado como componente; todavía no está conectado a
rutas protegidas. Por tanto, estas pruebas no acreditan rechazo HTTP de tokens
inválidos en los servicios de dominio.
El Gateway conserva la propagación de `Authorization`. La adopción de validación
en rutas protegidas de Material/Catalog/Search corresponde a sus tareas; este
cambio no sustituye el contexto local de autor de Material. La desactivación
impide nuevos logins, pero no revoca tokens ya emitidos antes de su expiración.

Para probar, registrar una cuenta con `POST /api/v1/auth/register` y utilizar
esas mismas credenciales en `/api/v1/auth/login`. Ya no se aceptan credenciales
arbitrarias de los antiguos ejemplos mock.

## Ejecutar

```bash
npm run start:dev   # desarrollo (watch)
npm run start       # compilar y ejecutar
```

Servicio en `http://localhost:3001` (prefijo `api/v1`).

Documentación OpenAPI/Swagger en `http://localhost:3001/api/docs`.

## Tests

```bash
npm run test      # unitarios
npm run test:e2e  # e2e
npm run build    # necesario antes de las pruebas de integración del registro
npm run test:integration # persistencia real; requiere PostgreSQL migrado y .env
npm run lint
```

`GET /api/v1/health` verifica además la conexión a PostgreSQL con `SELECT 1`
vía Prisma: responde `200` con `database: "connected"` cuando la base responde y
`503` con `database: "disconnected"` cuando no (el cuerpo conserva `status`,
`service` y `timestamp` en ambos casos). Los tests de health sustituyen Prisma
con un stub para ejecutarse sin PostgreSQL. Para comprobar la conexión real,
inicia `db-auth`, aplica las migraciones y ejecuta `npm run start:dev`: debe
aparecer `Conexión a PostgreSQL establecida`.

### Migración local de usuarios (#52)

La migración convierte `users.id` y `refresh_tokens.user_id` mediante
`ALTER COLUMN ... TYPE UUID USING ...::uuid`. Se ajustó el SQL generado por
`prisma migrate diff` para conservar los identificadores existentes en lugar
de eliminar y recrear las columnas. La clave foránea se retira durante la
conversión y se restaura con eliminación y actualización en cascada.
Todo se ejecuta en una transacción: un identificador inválido o una colisión
al convertir UUID impide aplicar parcialmente los cambios.

Con `db-auth` iniciado, ejecuta desde `backend/auth-service`:

```bash
npm exec -- prisma validate
npm run prisma:deploy
npm run prisma:generate
npm exec -- prisma migrate status
npm exec -- prisma migrate diff --from-schema-datasource prisma/schema.prisma --to-schema-datamodel prisma/schema.prisma --exit-code
npm run test:integration
```

El estado debe indicar que todas las migraciones están aplicadas y el diff debe
terminar con código `0` (sin diferencias). `prisma:deploy` aplica las migraciones
versionadas sin generar otras; también sirve para preparar una base local vacía.

Las pruebas de integración comprueban creación, consulta y actualización de
usuarios, UUID nativo, valores por defecto, correo único, rechazo de tokens
huérfanos y eliminación en cascada. Cada prueba revierte su transacción para
no dejar datos de prueba. La suite `register.e2e-spec.ts` valida el contrato HTTP con Prisma sustituido;
`registration.integration.cjs` ejecuta el registro real contra PostgreSQL, prueba
la colisión concurrente, el hash persistido, los roles y la exclusión de secretos.
Esta última elimina únicamente su usuario de prueba al terminar.
