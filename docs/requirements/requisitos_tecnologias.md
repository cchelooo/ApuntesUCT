# Especificación de Requisitos — ApuntesUCT

## 1. Alcance

ApuntesUCT es una plataforma académica para compartir, descubrir y evaluar material de estudio contextualizado a la comunidad universitaria.

El MVP debe mantener como núcleo:

- Autenticación.
- Catálogo académico.
- Subida y clasificación de material.
- Moderación.
- Búsqueda y filtros.
- Visualización/detalle.
- Descarga.
- Favoritos.
- Evaluaciones.
- Reportes.
- Verificación.
- Reputación.
- Posicionamiento.
- Versionado básico.

El proyecto debe ser implementado de manera incremental durante aproximadamente cuatro sprints.

---

# 2. Tecnologías seleccionadas

| Tecnología | Área | Uso |
|---|---|---|
| **Node.js 22 LTS** | Backend | Runtime de los servicios backend |
| **TypeScript 5.x** | Backend/Web | Lenguaje principal para reducir inconsistencias entre capas |
| **NestJS 11** | Backend | Framework para API Gateway y microservicios |
| **REST / HTTPS / JSON** | Comunicación | Comunicación entre clientes, Gateway y servicios |
| **Swagger / OpenAPI** | API | Documentación y contrato entre INT2 e INT4 |
| **PostgreSQL 17** | Persistencia | Datos estructurados del sistema |
| **Prisma ORM 6.x** | Persistencia | Acceso tipado a PostgreSQL y migraciones |
| **MinIO** | Archivos | Almacenamiento de documentos compatible con S3 |
| **React 19** | Web | Construcción de la interfaz web |
| **Vite** | Web | Herramienta de desarrollo/build para React |
| **TypeScript** | Web | Desarrollo tipado de la interfaz |
| **TanStack Query** | Web | Consumo, cache y sincronización de datos de la API |
| **React Router** | Web | Navegación de la aplicación |
| **Tailwind CSS** | Web | Estilos y diseño responsivo |
| **Flutter 3.x** | Mobile | Desarrollo de aplicación móvil multiplataforma |
| **Dart 3.x** | Mobile | Lenguaje de Flutter |
| **Riverpod** | Mobile | Manejo de estado |
| **Dio** | Mobile | Comunicación HTTP con la API |
| **go_router** | Mobile | Navegación |
| **Freezed** | Mobile | Modelos inmutables |
| **json_serializable** | Mobile | Serialización/deserialización JSON |
| **Docker** | Infraestructura | Contenerización de servicios |
| **Docker Compose** | Infraestructura | Orquestación local del MVP |
| **Jest** | Backend | Tests unitarios |
| **Supertest** | Backend | Tests de endpoints HTTP |
| **Vitest** | Web | Tests |
| **React Testing Library** | Web | Tests de componentes |
| **Flutter Test** | Mobile | Tests de aplicación y widgets |

### Decisiones relevantes

- **No se utilizará FastAPI/Python para el backend del MVP.**
- El backend será implementado con **NestJS + TypeScript**.
- No se utilizará HTML Vanilla.
- No se incorporará Elasticsearch/OpenSearch en el MVP debido a su incorporación añadiria bastante infraestructura como para terminarlas en 4 sprints.
- No se incorporará RabbitMQ/Kafka inicialmente; la comunicación entre servicios comenzará con REST para mantener el alcance controlable.

---

# 3. Arquitectura requerida

El sistema utilizará una arquitectura de **microservicios**.

Los clientes no accederán directamente a los servicios internos.

```text
                 ┌─────────────┐
                 │     Web     │
                 └──────┬──────┘
                        │
                 ┌──────▼──────┐
                 │ API Gateway │
                 └──────┬──────┘
                        │
        ┌───────────────┼────────────────┐
        │               │                │
        ▼               ▼                ▼
      Auth          Catalog           Material
        │               │                │
        │               │                └── MinIO
        │               │
        └───────────────┼────────────────┐
                        │                │
                        ▼                ▼
                     Quality          Search
```

Mobile utiliza el mismo API Gateway:

```text
Flutter
   ↓
API Gateway
   ↓
Microservicios
```

## Servicios iniciales

### Auth Service

Responsable de identidad, autenticación, usuarios y roles.

### Catalog Service

Responsable de universidad, carrera, asignatura, profesor y sus relaciones.

### Material Service

Responsable de materiales, metadatos, archivos, versiones y descargas.

### Quality Service

Agrupa las funciones de:

- evaluaciones;
- favoritos;
- reportes;
- moderación;
- verificación;
- reputación.

Se agrupan para mantener el proyecto realizable en cuatro sprints. La separación interna por módulos debe mantenerse.

### Search Service

Responsable de:

- búsqueda;
- filtros;
- ordenamiento;
- posicionamiento.

---

# 4. Requisitos Funcionales

| ID | Característica | Descripción |
|---|---|---|
| **RF-01** | Gestión de identidad y autenticación | Permite registro, inicio de sesión, cierre de sesión y recuperación de acceso cuando corresponda. El registro inicial estará restringido a correos institucionales `@uct.cl` o `@alu.uct.cl`. |
| **RF-02** | Clasificación y subida multiformato | Permite subir material académico y asociarlo a universidad, carrera, asignatura, profesor cuando corresponda, año y tipo de material. Los documentos locales tendrán inicialmente un límite de 15 MB. Los videos o archivos pesados podrán utilizar enlaces externos. |
| **RF-03** | Flujo de moderación | Todo material nuevo ingresa en estado `PENDING_REVIEW` y debe ser revisado antes de quedar publicado. |
| **RF-04** | Búsqueda contextual y filtros | Permite buscar material mediante texto y filtros por carrera, asignatura, profesor, año, tipo de material y valoración, entre otros disponibles. |
| **RF-05** | Previsualización multimedia | Permite visualizar documentos compatibles, especialmente PDF, sin obligar al usuario a descargar el archivo previamente. Los enlaces multimedia compatibles podrán mostrarse mediante contenido embebido seguro. |
| **RF-06** | Sistema colaborativo de evaluación y reputación | Permite calificar material de 1 a 5 estrellas y utilizar las evaluaciones y otras acciones relevantes para calcular reputación en backend. |
| **RF-07** | Módulo de reportes | Permite reportar material desactualizado, incorrecto, duplicado, inapropiado o defectuoso. Los reportes deben pasar por revisión. |
| **RF-08** | Favoritos | Permite a un usuario guardar y consultar materiales favoritos. |
| **RF-09** | Versionado básico | Permite conservar versiones anteriores de un material cuando exista una nueva versión. |
| **RF-10** | Verificación | Permite que un material sea marcado como verificado cuando cumple el proceso de revisión definido por el sistema. |
| **RF-11** | Posicionamiento | Ordena los resultados utilizando señales como relevancia, valoración, verificación, actualidad, reputación, reportes y uso. |
| **RF-12** | Administración | Permite a usuarios autorizados revisar materiales, resolver reportes, aprobar/rechazar contenido, retirar material y administrar elementos del catálogo según sus permisos. |

---

# 5. Requisitos No Funcionales

## RNF-01 — Arquitectura y acoplamiento

El sistema debe utilizar una arquitectura de microservicios con un API Gateway.

El backend será implementado mediante Node.js, TypeScript y NestJS.

La Web y Mobile deben consumir la misma API pública y la lógica de negocio no debe residir en los clientes.

Los clientes no deben conocer la implementación interna de los microservicios, Prisma, PostgreSQL ni MinIO.

**Criterio de aceptación:** una misma operación de negocio debe producir reglas y resultados equivalentes desde Web y Mobile.

---

## RNF-02 — Rendimiento y respuesta

Las operaciones habituales de consulta, especialmente búsqueda y carga de resultados, deben ofrecer una experiencia fluida bajo condiciones normales de uso.

Como objetivo práctico del MVP:

> Las consultas habituales deberían responder aproximadamente en **2 segundos o menos** bajo condiciones normales de red e infraestructura.

Los 2 segundos constituyen un **objetivo de rendimiento**, no una garantía absoluta para cualquier condición de red, dispositivo, carga o tamaño de respuesta.

Las pruebas de rendimiento deben registrar sus condiciones para que el resultado sea reproducible.

**Criterio de aceptación:** no se considerará cumplido el objetivo si existen consultas habituales que presentan tiempos de respuesta consistentemente elevados bajo condiciones normales del entorno definido para las pruebas.

---

## RNF-03 — Compatibilidad y UX/UI

La aplicación móvil será desarrollada con Flutter.

La interfaz web será desarrollada mediante un framework de componentes, utilizando React.

No se permitirá HTML Vanilla como tecnología principal de la interfaz web.

La interfaz deberá adaptarse a los tamaños de pantalla considerados por el MVP.

---

## RNF-04 — Seguridad de datos

El sistema debe:

- Validar entradas provenientes de clientes.
- Sanitizar datos y enlaces externos.
- Validar formato y tamaño de archivos.
- Evitar exposición directa de PostgreSQL.
- Evitar exposición directa de MinIO a los clientes.
- Aplicar autenticación y autorización en backend.
- Evitar almacenar archivos directamente en la raíz pública del servidor.
- Utilizar identificadores de almacenamiento no predecibles.
- Proteger credenciales y configuraciones sensibles.

---

## RNF-05 — Despliegue y portabilidad

Los componentes backend deben poder ejecutarse mediante Docker.

Docker Compose se utilizará para facilitar el entorno local del proyecto.

El sistema deberá poder desplegar como mínimo:

```text
Web
API Gateway
Auth Service
Catalog Service
Material Service
Quality Service
Search Service
PostgreSQL
MinIO
```

El proyecto deberá contar con un entorno de hosting para la demostración final.

---

## RNF-06 — Documentación de API

La API pública debe estar documentada mediante OpenAPI/Swagger.

La documentación debe incluir:

- endpoints;
- métodos;
- parámetros;
- headers;
- autenticación;
- requests;
- responses;
- códigos HTTP;
- errores;
- filtros y paginación cuando corresponda.

---

## RNF-07 — Mantenibilidad

Cada microservicio debe mantener una separación clara entre:

```text
Presentation
Application
Domain
Infrastructure
```

Las reglas de negocio importantes deben estar separadas de controladores, ORM y detalles de infraestructura.

---

## RNF-08 — Independencia de datos

Cada microservicio debe ser responsable de sus propios datos.

Para el MVP se permite utilizar una única instancia de PostgreSQL con esquemas separados por servicio.

No se permite que un servicio consulte directamente las tablas internas de otro servicio.

La comunicación entre servicios debe realizarse mediante sus contratos.

---

## RNF-09 — Integración entre plataformas

Web y Mobile deben consumir la misma API pública.

Mobile no implementará una API propia ni accederá directamente a PostgreSQL o MinIO.

Los cambios necesarios para Mobile deben resolverse mediante coordinación con INT2 y evolución documentada del contrato API.

---

## RNF-10 — Pruebas

El backend deberá contar con tests para los casos críticos del sistema.

Como mínimo deberán considerarse:

- autenticación;
- subida/creación de material;
- moderación;
- búsqueda;
- evaluaciones;
- reportes;
- favoritos.

La Web y Mobile deberán cubrir los componentes críticos de sus respectivas interfaces.

---

# 6. Reglas de negocio principales

### Usuarios

- Todo usuario debe iniciar sesión para subir material.
- Los usuarios registrados pueden descargar material publicado.
- Los usuarios pueden evaluar y reportar material.
- Los administradores pueden moderar contenido.

### Material

Todo material debe registrar, cuando corresponda:

```text
Universidad
Carrera
Asignatura
Profesor
Año
Tipo de material
```

Los materiales nuevos comienzan en:

```text
PENDING_REVIEW
```

Un material rechazado no aparece en las búsquedas normales.

Un material retirado tampoco aparece en las búsquedas normales.

### Reportes

Un reporte no elimina automáticamente un material.

Los reportes deben registrarse y revisarse.

Un material con reportes confirmados puede disminuir su visibilidad o volver a revisión según las reglas definidas.

### Reputación

La reputación:

- se calcula en backend;
- puede considerar aportes aprobados;
- puede considerar evaluaciones;
- puede considerar reportes confirmados;
- puede influir en el posicionamiento;
- no determina por sí sola que un material sea válido.

### Verificación

La etiqueta de material verificado indica que se cumplió el proceso de revisión establecido.

No significa que el sistema pueda garantizar la corrección absoluta del contenido.

---

# 7. División de responsabilidades INT2 / INT4

| Área | INT2 | INT4 |
|---|---:|---:|
| Web | ✅ | ❌ |
| API Gateway | ✅ | ❌ |
| Microservicios | ✅ | ❌ |
| PostgreSQL | ✅ | ❌ |
| Prisma | ✅ | ❌ |
| MinIO | ✅ | ❌ |
| Autenticación servidor | ✅ | ❌ |
| Reglas de negocio | ✅ | ❌ |
| Moderación servidor | ✅ | ❌ |
| Reputación | ✅ | ❌ |
| Ranking | ✅ | ❌ |
| Flutter | ❌ | ✅ |
| UI/UX Mobile | ❌ | ✅ |
| Estado Mobile | ❌ | ✅ |
| Consumo API | Coordinación | ✅ |
| Subida/descarga desde Mobile | API/Backend | Integración |
| Tests Mobile | ❌ | ✅ |

La API pública es el contrato entre ambos talleres.

---

# 8. Criterios de alcance para cuatro sprints 
(al menos esta seria la idea principal, puede cambiar dependiendo la velocidad de trabajo)

## Sprint 1

- Arquitectura de microservicios.
- API Gateway.
- Docker Compose.
- PostgreSQL.
- Prisma.
- MinIO.
- Base de Auth Service.
- Base de Catalog Service.
- OpenAPI inicial.
- Integración inicial de Mobile.

## Sprint 2

- Material Service.
- Subida.
- Descarga.
- Versionado básico.
- Catálogo completo.
- Búsqueda inicial.
- Integración Web/Mobile.

## Sprint 3

- Quality Service.
- Evaluaciones.
- Favoritos.
- Reportes.
- Moderación.
- Verificación.
- Reputación.
- Posicionamiento inicial.

## Sprint 4

- Integración completa.
- Refinamiento de búsqueda.
- Tests.
- Seguridad.
- Rendimiento.
- Documentación ().
- Docker/hosting.
- Corrección de errores.
- Demostración del MVP.

Las funcionalidades complementarias, como el editor Markdown/LaTeX, se implementarán solamente si el núcleo está estable.
