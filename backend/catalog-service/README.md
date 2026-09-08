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