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
| `role` | `Role` | `STUDENT`, `PROFESSOR` o `ADMIN`; por defecto `STUDENT`. |
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

### Reglas para implementar el registro

El esquema define la persistencia. El caso de uso de registro debe normalizar el
correo (quitar espacios exteriores y convertir a minúsculas) antes de guardarlo
o buscarlo, validar los dominios institucionales `@uct.cl` y `@alu.uct.cl`
según RF-01, y generar el hash de la contraseña antes de persistirla. El índice
único de `email` no normaliza mayúsculas por sí mismo. El registro público debe
asignar `STUDENT`; los roles privilegiados requieren un flujo autorizado.
Las respuestas de la API deben omitir `passwordHash`.

Estas validaciones y los endpoints de autenticación todavía no están
implementados; no las realiza el modelo de Prisma.

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
npm run test:integration # persistencia real; requiere PostgreSQL migrado y .env
npm run lint
```

El test HTTP de health sustituye Prisma para ejecutarse sin PostgreSQL. Para
comprobar la conexión real, inicia `db-auth`, aplica las migraciones y ejecuta
`npm run start:dev`: debe aparecer `Conexión a PostgreSQL establecida`.

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
no dejar datos de prueba. No implementan ni verifican los endpoints de registro.
