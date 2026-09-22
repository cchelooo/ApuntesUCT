# Catalog Service

Microservicio de universidad, carrera, asignatura, profesor y sus relaciones del ecosistema ApuntesUCT.

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

## Base de Datos

Este servicio utiliza **Prisma ORM** junto con PostgreSQL para la gestión del modelo de catálogo.

### Manejo de Campo `semester` en Asignaturas

- **Valor por defecto:** `1`
- **Comportamiento con datos existentes:** Durante la migración, todas las asignaturas preexistentes en la base de datos que carezcan de un semestre asignado recibirán automáticamente el valor por defecto `1` mediante una consulta `UPDATE` previa a la aplicación de la restricción `NOT NULL`.
- **Nuevos registros:** Si no se especifica el campo `semester` al crear una asignatura, la base de datos le asignará automáticamente el valor `1`.

## Requisitos

- Node.js 22 (`.nvmrc` en la raíz del repo).
- Instancia de PostgreSQL. Con Docker Compose en la raíz del repo se levanta `db-catalog` (puerto `5433`, base `catalog_db`).

## Setup

```bash
npm install
cp .env.example .env   # configurar DATABASE_URL según el entorno
npm run prisma:generate
```

## Base de datos

```bash
npm run prisma:migrate   # aplica la migración inicial en desarrollo
npm run prisma:studio    # explorar datos
```

```bash
npx prisma migrate dev   # aplicar migraciones pendientes en el entorno local
npm run prisma:generate  # regenerar cliente de prisma
```

## Ejecutar

```bash
npm run start:dev   # desarrollo (watch)
npm run start       # compilar y ejecutar
```

Servicio en `http://localhost:3002` (prefijo `api/v1`).

Documentación OpenAPI/Swagger en `http://localhost:3002/api/docs`.

## Tests

```bash
npm run test      # unitarios
npm run test:e2e  # e2e
npm run lint
```

### 🛠️ Procedimiento de Recuperación ante error P3009 (Failed Migrations)

Si al ejecutar `npx prisma migrate deploy` se obtiene el error `P3009: Migrate found failed migrations in the target database`, siga estos pasos de recuperación sin pérdida de datos:

1. **Marcar la migración fallida como resuelta:**
   Ejecute el siguiente comando indicando el nombre de la carpeta de la migración afectada (ej. `20260901000000_add_semester_to_subject`):

```bash
npx prisma migrate resolve --applied "NOMBRE_DE_LA_MIGRACION"
```

   (Si la migración no se llegó a aplicar en la BD física, use --rolled-back en lugar de --applied)

2. **Re-ejecutar el despliegue de migraciones**

```bash
npx run prisma:deploy
```

### 🧪 Ejecución de Pruebas de Migración
Para ejecutar la prueba automatizada de la migración de base de datos (verificación de conservación de datos y asignación por defecto del campo `semester`):

```bash
npm run test:migration
```
(Si se quiere correr prueba de migración, ejecutar el comando en catalog-service)

## 🛠️ Ejecución de Base de Datos y Seeding

Para desplegar la base de datos y poblar los datos de prueba del catálogo de forma segura e idempotente, ejecuta los siguientes comandos desde la carpeta del servicio (`backend/catalog-service`):

```bash
# 1. Generar los tipos del cliente de Prisma
npm run prisma:generate

# 2. Desplegar migraciones pendientes en PostgreSQL
npm run prisma:deploy

# 3. Poblar o actualizar los datos de prueba (idempotente via upsert)
npm run prisma:seed
```





