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
│   │   │   └── api_config.dart       # URL del API Gateway (#39): API_GATEWAY_URL o 10.0.2.2 en emulador
│   │   ├── errors/
│   │   │   ├── api_exception.dart    # Excepción centralizada con fromDioException (#40)
│   │   │   └── error_messages.dart   # Mensajes de error reutilizables para la UI
│   │   ├── network/
│   │   │   ├── api_client.dart       # Cliente Dio con ErrorInterceptor y logs (#38, #40)
│   │   │   ├── api_response.dart     # Helper AsyncValue para respuestas API (#40)
│   │   │   └── error_interceptor.dart # Interceptor unificado de errores (#40)
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
│   │   │   │   ├── models/           # Modelos de respuesta Auth (#65)
│   │   │   │   └── mock_auth_repository.dart  # Contrato AuthRepository + mock con login/registro
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
│   ├── register_navigation_test.dart # Registro exitoso navega al Home
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
| `lib/core/config/` | Configuración del API Gateway (#39): `API_GATEWAY_URL` o selección automática (`10.0.2.2` en emulador Android, `localhost` en el resto). |
| `lib/core/errors/` | Excepción centralizada `ApiException` con `fromDioException` (#40) más helpers de mensajes para la UI. |
| `lib/core/network/` | Cliente Dio (`ApiClient`), interceptor unificado de errores y helper `ApiResponseHandler` (#38, #40). |
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
