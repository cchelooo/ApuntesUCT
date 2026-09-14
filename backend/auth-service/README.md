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
npm ci
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
npm run prisma:migrate   # aplica la migración inicial en desarrollo
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
npm run lint
```

El test HTTP de health sustituye Prisma para ejecutarse sin PostgreSQL. Para
comprobar la conexión real, inicia `db-auth`, aplica las migraciones y ejecuta
`npm run start:dev`: debe aparecer `Conexión a PostgreSQL establecida`.
