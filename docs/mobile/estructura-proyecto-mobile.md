# Estructura del proyecto mobile

Documento actualizado el 22 de septiembre de 2026 a partir de la estructura
presente en `main` (`7d80289`). No se modificó código fuente como parte de esta
revisión.

## Estado de las tareas revisadas

| Issue | Tarea | Estado en GitHub | Avance verificado en el código |
|---|---|---|---|
| #35 | Configurar navegación base con `go_router` | Cerrada | `main.dart` usa `GoRouter`, `MaterialApp.router` y rutas principales. |
| #36 | Crear rutas vacías para Login, Registro, Catálogo y Perfil | Cerrada | Las rutas `/login`, `/register`, `/catalog` y `/profile` existen; catálogo y perfil ya tienen pantallas reales. |
| #37 | Validar estructura de carpetas mobile con el equipo | Cerrada | La app está separada en `core`, `features`, `models`, `providers` y tests. |
| #49 | Maquetar pantalla Login Mobile | Cerrada | `LoginScreen`, validadores, widgets compartidos y pruebas de UI/responsive presentes. |
| #50 | Maquetar pantalla Registro Mobile | Cerrada | `RegisterScreen`, validaciones institucionales, confirmación de contraseña y prueba de navegación presentes. |
| #64 | Crear modelos de respuesta Catálogo Mobile | Lista para cierre | Existen `UniversityModel`, `CareerModel`, `SubjectModel` y `ProfessorModel`; la integración actual usa `CatalogItem` para aplanar la respuesta del catálogo. |
| #65 | Crear modelos de respuesta Auth Mobile | Lista para cierre | Existen modelos de request/response y tokens en `features/auth/data/models/`, con `fromJson`, `toJson`, mocks y representación segura de tokens. |
| #79 | Pulir pantallas Login y Registro Mobile | Lista para cierre | La UI tiene tema UCT claro/oscuro, layout responsive, validaciones, widgets reutilizables y tests. |
| #80 | Validar flujo Auth Mobile con API | Abierta / Todo | Pendiente: Login y Registro todavía usan `MockAuthRepository`; no existe `AuthApi` ni repositorio remoto en `main`. |

### Evidencia formal

- Las issues #35, #36, #37, #49 y #50 aparecen cerradas en GitHub.
- El PR #146 fue integrado y contiene el avance de las pantallas; este commit
  agrega referencias de cierre para #35, #36, #37, #49, #50, #64, #65 y #79.
- La issue #80 se mantiene abierta porque falta la API Auth real. El flujo actual
  es funcional mediante `MockAuthRepository` y queda cubierto por pruebas.
- La validación ejecutada sobre `main` fue `flutter analyze` sin issues y
  `flutter test` con **44 pruebas aprobadas**.

## Árbol de directorios

```text
mobile/
├── android/                                  # Proyecto Android nativo y configuración Gradle
├── ios/                                      # Proyecto iOS nativo y configuración Xcode
├── lib/                                      # Código Dart de la aplicación
│   ├── core/                                 # Infraestructura transversal
│   │   ├── config/
│   │   │   └── api_config.dart               # URLs del Gateway y Catalog Service por plataforma
│   │   ├── errors/
│   │   │   ├── api_exception.dart            # Excepción centralizada para Dio (#40)
│   │   │   └── error_messages.dart           # Mensajes de error mostrables en la UI
│   │   ├── network/
│   │   │   ├── api_client.dart               # Cliente Dio base e interceptor de errores
│   │   │   ├── api_response.dart             # Conversión de peticiones a AsyncValue
│   │   │   └── error_interceptor.dart         # Normalización de DioException
│   │   ├── theme/
│   │   │   ├── app_theme.dart                # Temas claro y oscuro
│   │   │   └── uct_palette.dart              # Paleta institucional UCT
│   │   ├── validation/
│   │   │   └── validators.dart               # Validaciones de formularios
│   │   └── widgets/                          # Componentes visuales reutilizables
│   │       ├── app_button.dart
│   │       ├── app_card.dart
│   │       ├── app_horizontal_list.dart
│   │       ├── app_navigation_bar.dart
│   │       ├── app_password_field.dart
│   │       ├── app_primary_button.dart
│   │       ├── app_section_header.dart
│   │       ├── app_text_field.dart
│   │       ├── auth_scaffold.dart
│   │       ├── empty_state.dart
│   │       ├── error_state.dart
│   │       ├── form_error_banner.dart
│   │       ├── institutional_email_field.dart
│   │       ├── loading_state.dart
│   │       ├── theme_toggle_button.dart
│   │       └── widgets.dart                  # Barrel export
│   ├── features/                             # Módulos funcionales por dominio
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── mock_auth_repository.dart # AuthRepository mock y estado Riverpod
│   │   │   │   └── models/                   # Modelos de request/response Auth (#65)
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       └── register_screen.dart
│   │   ├── catalog/
│   │   │   ├── data/catalog_repository.dart # Consulta y adaptación del catálogo
│   │   │   ├── domain/catalog_item.dart     # Modelo de UI del catálogo
│   │   │   └── presentation/                # Pantalla, provider y tarjeta de material
│   │   ├── home/
│   │   │   ├── domain/material_card_data.dart
│   │   │   └── presentation/                # Home, provider y widgets de cursos/materiales
│   │   └── profile/
│   │       ├── domain/profile_models.dart
│   │       └── presentation/                # Perfil, provider, extensiones y widgets
│   ├── models/                               # Modelos globales Auth/Catálogo
│   │   ├── user_model.dart
│   │   ├── university_model.dart             # Modelo base de catálogo (#64, avance heredado)
│   │   ├── career_model.dart                 # Modelo base de catálogo (#64, avance heredado)
│   │   ├── subject_model.dart                # Modelo base de catálogo (#64, avance heredado)
│   │   ├── professor_model.dart              # Modelo base de catálogo (#64, avance heredado)
│   │   └── models.dart                       # Barrel export
│   ├── providers/
│   │   └── theme_mode_provider.dart          # Estado global del tema con Riverpod
│   └── main.dart                              # Entrada, router y configuración MaterialApp
├── test/                                     # Tests unitarios y de widgets
│   ├── core/errors/api_exception_test.dart
│   ├── core/theme/app_theme_test.dart
│   ├── core/widgets/                         # Tests de componentes base y estados
│   ├── features/auth/data/mock_auth_repository_test.dart
│   ├── features/catalog/                     # Tests de repositorio y pantalla
│   ├── features/profile/presentation/        # Tests de pantalla de perfil
│   ├── screens/home_screen_test.dart
│   ├── register_navigation_test.dart         # Registro exitoso navega a Home
│   ├── responsive_auth_test.dart             # Login/Registro en portrait y landscape
│   └── widget_test.dart                      # Flujo visual de autenticación
├── pubspec.yaml                              # Dependencias Flutter/Dio/Riverpod/GoRouter
├── pubspec.lock                              # Versiones resueltas
└── analysis_options.yaml                     # Reglas del analizador
```

## Responsabilidad por capa

| Carpeta | Responsabilidad |
|---|---|
| `android/` | Integración nativa Android: Gradle, manifest, permisos y configuración de la aplicación. |
| `ios/` | Integración nativa iOS: Xcode, assets, launch screen y configuración de Runner. |
| `lib/core/` | Infraestructura compartida: red, errores, tema, validación y widgets base. |
| `lib/core/config/` | Resolución de URLs. `ApiConfig` usa `API_GATEWAY_URL`/`CATALOG_SERVICE_URL`, `10.0.2.2` en emulador Android y `localhost` en otras plataformas locales. |
| `lib/core/network/` | Cliente Dio, interceptor de errores y representación de estados asíncronos. |
| `lib/core/theme/` | Tema Material 3, colores institucionales y consistencia visual. |
| `lib/core/validation/` | Reglas de validación de nombre, correo institucional, contraseñas y confirmación. |
| `lib/core/widgets/` | Componentes compartidos para formularios, navegación, estados loading/error/empty y tarjetas. |
| `lib/features/auth/` | Login, registro y estado mock de autenticación con Riverpod. La integración real queda pendiente en #80. |
| `lib/features/catalog/` | Consulta del catálogo, adaptación de respuestas, búsqueda y presentación de materiales. |
| `lib/features/home/` | Pantalla principal, cursos, materiales y navegación hacia otras secciones. |
| `lib/features/profile/` | Perfil, edición visual, cursos, insignias y grilla de materiales. |
| `lib/models/` | Modelos globales de usuario y entidades académicas base. |
| `lib/providers/` | Providers globales que no pertenecen a una feature concreta. |
| `test/` | Pruebas unitarias, de widgets, responsive e integración de providers/pantallas. |

## Pendiente identificado

- #80: implementar y validar el consumo real de Auth cuando el API esté
  disponible. Mientras tanto, el flujo mock es funcional.
