# Estructura del proyecto mobile

Este documento describe la organización de la aplicación Flutter ubicada en `mobile/`.

## Árbol de directorios

```text
mobile/
├── android/                          # Proyecto Android nativo (Gradle, manifests, íconos)
│   ├── app/src/main/AndroidManifest.xml
│   └── build.gradle.kts
├── ios/                              # Proyecto iOS nativo (Xcode, assets, launch screen)
│   ├── Runner/
│   └── Runner.xcodeproj/
├── lib/                              # Código Dart de la app
│   ├── app/                          # Configuración global de la app (pendiente)
│   ├── core/                         # Infraestructura compartida entre toda la app
│   │   ├── config/
│   │   │   └── app_config.dart       # Constantes: URLs, timeouts, flags de debug/logs
│   │   ├── errors/
│   │   │   ├── api_error_model.dart  # Modelo del JSON de error del backend
│   │   │   ├── api_exception.dart    # Jerarquía de excepciones de dominio (Network, Timeout, 401, etc.)
│   │   │   └── error_messages.dart   # Mensajes de error reutilizables
│   │   ├── network/
│   │   │   ├── api_client.dart       # Cliente HTTP con Dio, interceptores, tokens y mapeo de errores
│   │   │   └── token_store.dart      # Almacenamiento en memoria del access/refresh token
│   │   ├── theme/
│   │   │   ├── app_theme.dart        # Tema claro/oscuro de la app
│   │   │   └── uct_palette.dart      # Colores institucionales UCT
│   │   ├── validation/
│   │   │   └── validators.dart       # Validaciones de formularios (email UCT, contraseña, etc.)
│   │   └── widgets/                  # Widgets reutilizables
│   │       ├── app_password_field.dart
│   │       ├── app_primary_button.dart
│   │       ├── app_text_field.dart
│   │       ├── auth_scaffold.dart    # Layout responsive de Login/Registro
│   │       ├── form_error_banner.dart
│   │       ├── institutional_email_field.dart
│   │       ├── theme_toggle_button.dart
│   │       └── widgets.dart          # Barrel export
│   ├── features/                     # Módulos por funcionalidad (auth, catalog, library, etc.)
│   │   ├── auth/
│   │   │   ├── data/                 # Capa de datos de autenticación
│   │   │   │   ├── models/           # DTOs de request/response del API
│   │   │   │   ├── auth_api.dart     # Llamadas HTTP a /auth
│   │   │   │   ├── auth_providers.dart
│   │   │   │   ├── mock_auth_repository.dart  # Repositorio mock para pruebas sin backend
│   │   │   │   └── remote_auth_repository.dart # Repositorio contra API real
│   │   │   ├── domain/               # Lógica de negocio pura (pendiente)
│   │   │   └── presentation/         # Pantallas de autenticación
│   │   │       ├── login_screen.dart
│   │   │       └── register_screen.dart
│   │   ├── catalog/
│   │   ├── library/
│   │   ├── profile/
│   │   └── search/                   # Estructura data/domain/presentation reservada
│   ├── models/                       # Modelos globales compartidos entre features
│   │   ├── user_model.dart
│   │   ├── career_model.dart
│   │   ├── subject_model.dart
│   │   ├── professor_model.dart
│   │   └── university_model.dart
│   ├── providers/
│   │   └── theme_mode_provider.dart  # Riverpod: modo claro/oscuro/sistema
│   ├── shared/                       # Utilidades transversales (pendiente)
│   └── main.dart                     # Punto de entrada, router GoRouter y HomeScreen
├── test/                             # Tests del proyecto
│   ├── core/errors/api_exception_test.dart
│   ├── responsive_auth_test.dart
│   └── widget_test.dart
├── pubspec.yaml                      # Dependencias (Riverpod, GoRouter, Dio, etc.)
├── pubspec.lock                      # Versiones resueltas
└── analysis_options.yaml             # Reglas del linter
```

## Responsabilidad por capa

| Carpeta | Responsabilidad |
|---------|-----------------|
| `android/` | Proyecto Android nativo generado por Flutter. Aquí se configuran permisos, íconos, nombre de app y firma. |
| `ios/` | Proyecto iOS nativo generado por Flutter. Contiene configuración de Xcode, assets y launch screen. |
| `lib/app/` | Configuración global de la app (por ejemplo, inicialización de providers o servicios). Actualmente reservado. |
| `lib/core/` | Código transversal que no pertenece a una feature específica: tema, errores, red, validaciones y widgets base. |
| `lib/core/config/` | Constantes de configuración: URL base del API Gateway, timeouts y flags de logs. |
| `lib/core/errors/` | Modelos y excepciones de dominio para aislar la UI de los detalles HTTP. |
| `lib/core/network/` | Cliente HTTP (`ApiClient`) basado en Dio, interceptores y almacenamiento de tokens (`TokenStore`). |
| `lib/core/theme/` | Paleta de colores UCT y temas claro/oscuro de Material 3. |
| `lib/core/validation/` | Validadores reutilizables para formularios (email institucional, contraseñas, etc.). |
| `lib/core/widgets/` | Widgets genéricos usados en varias pantallas: botones, campos de texto, scaffold de auth, etc. |
| `lib/features/` | Módulos organizados por funcionalidad. Cada feature tiene sus propias capas `data`, `domain` y `presentation`. |
| `lib/features/auth/` | Login, registro, logout y estado de autenticación con Riverpod. |
| `lib/models/` | Modelos globales compartidos entre varias features (usuario, carrera, asignatura, etc.). |
| `lib/providers/` | Providers globales de Riverpod que no pertenecen a una feature específica, como el modo de tema. |
| `lib/shared/` | Utilidades transversales como extensiones o helpers. Actualmente reservado. |
| `lib/main.dart` | Punto de entrada de la app, configuración del router (`GoRouter`) y pantalla de inicio. |
| `test/` | Tests unitarios y de widget del proyecto. |

## Notas

- La app sigue una arquitectura por capas dentro de cada `feature`: `data` (fuentes de datos), `domain` (lógica de negocio) y `presentation` (UI).
- `core/` centraliza la infraestructura para evitar duplicación entre features.
- Los tests actuales cubren el mapeo de errores de red y la adaptación responsive de las pantallas de autenticación.
