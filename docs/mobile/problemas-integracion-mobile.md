# Registro de Problemas de Integración — Mobile (INT4)

**Sprint 1 · Semana 3** — Registro formal de problemas técnicos, discrepancias de red, formatos de datos y compatibilidad detectados durante la integración de la aplicación móvil de ApuntesUCT con el API Gateway y los microservicios de backend.

> **Propósito (Issue #70):** Registrar la evidencia, causa raíz, impacto y solución aplicada para cada obstáculo técnico identificado durante las tareas de integración con el equipo INT2 (Web + Backend).

---

## 1. Matriz de problemas detectados

| ID | Área / Ámbito | Problema detectado | Impacto en Mobile | Estado / Solución |
|---|---|---|---|:---:|
| **P-01** | Red / Emulador | `localhost` inaccesible desde emulador Android | Fallo inmediato de conexión (`Connection refused`) | **Resuelto** (`10.0.2.2`) |
| **P-02** | Red / Físico | Conexión con IP LAN bloqueada por firewall | Timeout en solicitudes Dio (`connectTimeout`) | **Resuelto** (`--dart-define`) |
| **P-03** | Arquitectura | Gateway sin proxy para el servicio de Catálogo | Error `404 Not Found` en `:3000/api/v1/catalog` | **Resuelto** (Bypass `:3002`) |
| **P-04** | Formato API | Error 502 del proxy no respeta esquema de 3 campos | Error al deserializar respuestas de fallo | **Resuelto** (Parser flexible) |
| **P-05** | Formato API | Campo `message` alternante (`String` vs `List<String>`) | `TypeError` en tiempo de ejecución en Mobile | **Resuelto** (`ApiException`) |
| **P-06** | Contrato de datos | Backend entrega árbol anidado; UI requiere lista plana | Pantalla de catálogo no podía renderizar datos | **Resuelto** (Mapeo en Repository) |
| **P-07** | Búsqueda | Falta de endpoint o parámetro de búsqueda en `/catalog` | Buscador de catálogo inoperativo en backend | **Resuelto** (Filtro en memoria) |
| **P-08** | Autenticación | Ausencia de endpoints reales de registro, refresh y logout | Bloqueo de navegación de usuarios sin backend | **Resuelto** (Modo híbrido / demo) |

---

## 2. Detalle técnico de cada problema

### 2.1 Problema P-01: Resolución de IP local y loopback en Emulador Android

* **Contexto:** Durante las primeras pruebas de integración, el cliente HTTP (`ApiClient`) apuntaba a `http://localhost:3000/api/v1`.
* **Causa raíz:** En la arquitectura del emulador Android (QEMU/AVD), `localhost` y `127.0.0.1` refieren a la interfaz de red interna del propio dispositivo virtual, no a la máquina host donde corren NestJS y el Gateway.
* **Diagnóstico:** Dio arrojaba `DioException [connection error]: Connection refused`.
* **Solución aplicada:**
  En `mobile/lib/core/config/api_config.dart`, se implementó detección automática de plataforma:
  ```dart
  if (!kIsWeb && Platform.isAndroid) {
    return validateUrl('http://10.0.2.2:3000/api/v1');
  }
  return validateUrl('http://localhost:3000/api/v1');
  ```
  `10.0.2.2` es el alias que el router virtual de Android utiliza para rutear tráfico al loopback del computador anfitrión.

---

### 2.2 Problema P-02: Conectividad en dispositivos físicos sobre la red local

* **Contexto:** Pruebas de usabilidad y rendimiento ejecutadas en smartphones Android reales conectados por Wi-Fi.
* **Causa raíz:** Un dispositivo físico no puede resolver ni `localhost` ni `10.0.2.2`. Requiere la IP privada LAN del computador (ej. `192.168.1.50`). Adicionalmente, el firewall del sistema operativo anfitrión bloqueaba las conexiones entrantes en los puertos `3000` y `3002`.
* **Solución aplicada:**
  1. Se habilitó la inyección en tiempo de compilación mediante `String.fromEnvironment('API_GATEWAY_URL')` y `String.fromEnvironment('CATALOG_SERVICE_URL')`.
  2. Se documentó en `mobile/README.md` la instrucción de ejecución para dispositivos físicos:
     ```bash
     flutter run -d <device-id> \
       --dart-define=API_GATEWAY_URL=http://<IP-HOST-LAN>:3000/api/v1 \
       --dart-define=CATALOG_SERVICE_URL=http://<IP-HOST-LAN>:3002/api/v1
     ```
  3. Se añadieron excepciones de entrada en el firewall de Windows para Node.js en los puertos respectivos.

---

### 2.3 Problema P-03: Inexistencia de proxy en API Gateway para Catalog Service

* **Contexto:** La arquitectura lógica del proyecto establece un único punto de entrada a través del API Gateway en el puerto `3000`.
* **Causa raíz:** El módulo de proxy del Gateway (`backend/api-gateway/src/modules/proxy/proxy.module.ts`) solo reescribe y reenvía rutas hacia el Auth Service (`/api/v1/auth`), careciendo de reglas de proxy para el servicio de catálogo. Enviar `GET /api/v1/catalog` al Gateway retornaba:
  ```json
  {
    "statusCode": 404,
    "message": "Cannot GET /api/v1/catalog",
    "error": "Not Found"
  }
  ```
* **Solución aplicada (Bypass temporal documentado):**
  Para no detener el avance de Mobile mientras el equipo de Backend implementa el proxy unificado:
  - Se creó `ApiConfig.catalogBaseUrl` apuntando directamente a `http://10.0.2.2:3002/api/v1` en Android (`http://localhost:3002/api/v1` en escritorio).
  - Se configuró `catalogApiClientProvider` en Riverpod consumiendo dicho puerto independiente.
  - La excepción quedó formalmente documentada en `docs/mobile/integracion-api-mobile.md` (sección 1.2).

---

### 2.4 Problema P-04: Inconsistencia en el formato de error 502 del Gateway

* **Contexto:** Estandarización de captura de errores HTTP en Mobile.
* **Causa raíz:** La documentación general asumía que toda respuesta de error seguiría la tríada de NestJS: `{ statusCode, message, error }`. Sin embargo, cuando el servicio de Auth está caído, el middleware de proxy (`http-proxy-middleware`) responde con un JSON de solo dos campos:
  ```json
  { "statusCode": 502, "message": "Auth Service no disponible" }
  ```
* **Impacto en Mobile:** Si el modelo de error esperaba obligatoriamente el campo `"error"`, la deserialización fallaba provocando excepciones internas.
* **Solución aplicada:**
  En `ApiException.fromDioException` (`mobile/lib/core/errors/api_exception.dart`), se relajó la obligatoriedad del campo `error`, extrayendo `message` y `statusCode` como valores base y considerando `error` como opcional.

---

### 2.5 Problema P-05: Tipado dinámico del campo `message` de NestJS (`String` vs `List<String>`)

* **Contexto:** Visualización de mensajes de error de validación en pantallas de autenticación (Login/Registro).
* **Causa raíz:**
  - Los errores generados manualmente en controladores (ej. `throw new BadRequestException('Credenciales inválidas')`) entregan `message` como un `String`.
  - Los errores generados automáticamente por el `ValidationPipe` con `class-validator` (ej. al enviar un correo sin formato o contraseña en blanco) entregan `message` como un `List<dynamic>`:
    ```json
    {
      "statusCode": 400,
      "message": [
        "email must be an email",
        "password debe contener al menos un carácter que no sea espacio en blanco"
      ],
      "error": "Bad Request"
    }
    ```
* **Impacto en Mobile:** Código que ejecutaba `data['message'] as String` lanzaba un `TypeError: type 'List<dynamic>' is not a subtype of type 'String'`.
* **Solución aplicada:**
  Se implementó lógica defensiva en `ApiException`:
  ```dart
  String resolvedMessage = 'Error inesperado del servidor';
  final rawMessage = data['message'];
  if (rawMessage is String) {
    resolvedMessage = rawMessage;
  } else if (rawMessage is List && rawMessage.isNotEmpty) {
    resolvedMessage = rawMessage.map((e) => e.toString()).join('\n');
  }
  ```

---

### 2.6 Problema P-06: Discrepancia estructural en Catálogo (Árbol relacional vs Lista plana)

* **Contexto:** Despliegue de asignaturas y materiales en la pantalla de Catálogo (`CatalogScreen`).
* **Causa raíz:**
  - El backend (`GET /catalog`) devuelve una estructura arbórea:
    `Universidad[] -> Carrera[] -> Asignatura[]`
  - La interfaz de usuario móvil requiere una lista homogénea de tarjetas (`CatalogItem`) para búsqueda, filtrado y renderizado en `ListView`.
* **Solución aplicada:**
  En `mobile/lib/features/catalog/data/catalog_repository.dart`, se implementó un parser defensivo en dos fases:
  1. Itera por universidades y sus carreras activas, extrayendo las asignaturas anidadas y mapeándolas a instancias de `CatalogItem` (asignando la universidad como autor y la carrera como área temática).
  2. Si el backend en el futuro cambia a una respuesta paginada plana (`data: [...]`), el parser contempla esa rama como alternativa.

---

### 2.7 Problema P-07: Ausencia de búsqueda por texto del lado del servidor

* **Contexto:** Barra de búsqueda en la pantalla de Catálogo (`CatalogScreen`).
* **Causa raíz:** El endpoint `GET /catalog` del backend no recibe parámetros de búsqueda por query string (`?q=` o `?search=`). El endpoint `/catalog/filter` solo admite IDs jerárquicos secuenciales (`universityId`, `careerId`, etc.), no cadenas de texto libre.
* **Solución aplicada:**
  El filtrado textual se implementó en memoria en el cliente móvil dentro de `CatalogRepository.getCatalog(search: query)`:
  ```dart
  if (search != null && search.trim().isNotEmpty) {
    final query = search.trim().toLowerCase();
    return items.where((item) {
      return item.title.toLowerCase().contains(query) ||
          item.author.toLowerCase().contains(query) ||
          item.subject.toLowerCase().contains(query);
    }).toList();
  }
  ```
  Esto permite filtrado instantáneo en la UI mientras el servicio Search (`/api/v1/search`) es implementado en sprints futuros.

---

### 2.8 Problema P-08: Dependencia de backend para autenticación y sesiones

* **Contexto:** Ejecución de pruebas de interfaz, flujos de navegación y trabajo de diseño desconectado del backend.
* **Causa raíz:** El endpoint `POST /auth/login` del backend es una simulación temporal con JWT sin firma (`alg: none`) y no existen endpoints para registro ni logout. Si un integrante del equipo móvil no cuenta con PostgreSQL o Node.js activos, la app quedaba bloqueada al iniciar.
* **Solución aplicada:**
  1. Se diseñó el contrato `AuthRepository` con dos implementaciones intercambiables: `DioAuthRepository` (llamadas reales con Dio) y `MockAuthRepository` (simulación local con latencia artificial).
  2. Se configuró `authDemoModeProvider`:
     - Modo normal: usa `DioAuthRepository` hacia el Gateway para detectar fallos reales de integración.
     - Modo demo (`--dart-define=AUTH_DEMO_MODE=true`): conmuta a `MockAuthRepository`, permitiendo pruebas completas de UI y navegación desconectada.

---

## 3. Estado de validación tras las correcciones

| Componente | Validación | Resultado |
|---|---|:---:|
| `flutter analyze` | Análisis estático de todos los archivos de red y repositorios | **0 errores / 0 advertencias** |
| `flutter test` | Batería de 65 pruebas unitarias, de integración y navegación | **65 / 65 pruebas superadas (100%)** |
| Pruebas Dio Auth | Validación de respuestas 200, 400 y 502 con cliente mock | **Aprobado** (`login_dio_test.dart`) |
| Pruebas Catálogo | Validación de árbol anidado, búsqueda y caídas de servidor | **Aprobado** (`catalog_api_errors_test.dart`) |
| Ejecución en Emulador | Despliegue en Android API 37 con gestión limpia de errores de red | **Aprobado** (Render de `ErrorState`) |

---

## 4. Referencias y documentación relacionada

- [Soporte de integración con backend](integracion-api-mobile.md) — endpoints disponibles, puertos y convenciones.
- [README de Mobile](../../mobile/README.md) — instrucciones de ejecución con parámetros `--dart-define`.
- [Configuración de API de Mobile](../../mobile/lib/core/config/api_config.dart) — resolución de URLs y manejo de excepciones.
- [Repositorio de autenticación con Dio](../../mobile/lib/features/auth/data/dio_auth_repository.dart) — consumo del endpoint mock de login.
- [Repositorio de catálogo con parser defensivo](../../mobile/lib/features/catalog/data/catalog_repository.dart) — transformación de árbol y filtrado local.
