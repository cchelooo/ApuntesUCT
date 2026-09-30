# ApuntesUCT Mobile

Aplicación móvil de ApuntesUCT desarrollada con Flutter y Dart.

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/install) en el canal `stable` y disponible en el `PATH`.
- Flutter 3.47.2 con Dart 3.13.2, versiones con las que se creó y verificó el proyecto.
- Un dispositivo físico conectado o un emulador configurado.
- Para Android: Android Studio y Android SDK.
- Para iOS: macOS con Xcode y CocoaPods.

Comprueba el entorno antes de ejecutar la aplicación:

```bash
flutter --version
flutter doctor
```

Resuelve los errores que `flutter doctor` indique para la plataforma que utilizarás.

## Instalar dependencias

Desde la raíz del repositorio:

```bash
cd mobile
flutter pub get
```

`flutter pub get` instala las versiones compatibles registradas en `pubspec.yaml` y `pubspec.lock`. No es necesario ejecutar `flutter pub upgrade` para iniciar el proyecto.

## Ejecutar la aplicación

Lista los dispositivos disponibles:

```bash
flutter devices
```

Si solo hay uno disponible, ejecuta:

```bash
flutter run
```

Si hay varios, selecciona uno mediante su identificador:

```bash
flutter run -d <device-id>
```

Para consultar o iniciar un emulador configurado:

```bash
flutter emulators
flutter emulators --launch <emulator-id>
```

## Configuración de red y conexión con API Gateway

La aplicación móvil se conecta con el ecosistema de backend a través del **API Gateway** (`:3000`) para autenticación y salud, y directamente con el **Catalog Service** (`:3002`) para el catálogo académico (excepción arquitectónica temporal documentada en [`docs/mobile/integracion-api-mobile.md`](../docs/mobile/integracion-api-mobile.md)).

Las URLs base se resuelven mediante la clase `ApiConfig` (`lib/core/config/api_config.dart`) y pueden ser parametrizadas en tiempo de compilación con `--dart-define`.

### Variables de configuración disponibles

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `API_GATEWAY_URL` | Android: `http://10.0.2.2:3000/api/v1`<br>Desktop/Web: `http://localhost:3000/api/v1` | URL base del API Gateway (Auth y salud). |
| `CATALOG_SERVICE_URL` | Android: `http://10.0.2.2:3002/api/v1`<br>Desktop/Web: `http://localhost:3002/api/v1` | URL base directa del Catalog Service. |
| `AUTH_DEMO_MODE` | `false` | Si se define en `true`, activa `MockAuthRepository` para demostraciones o desarrollo offline sin requerir el backend levantado. |

### Ejemplos de ejecución según entorno

> **Nota sobre emuladores Android:** La dirección `127.0.0.1` o `localhost` dentro de un emulador apunta al propio emulador. Para acceder al localhost de tu máquina host se utiliza el alias especial `10.0.2.2`.

#### 1. Emulador Android (valores por defecto o explícitos)

```bash
flutter run \
  --dart-define=API_GATEWAY_URL=http://10.0.2.2:3000/api/v1 \
  --dart-define=CATALOG_SERVICE_URL=http://10.0.2.2:3002/api/v1
```

#### 2. Escritorio / Localhost / Web

```bash
flutter run \
  --dart-define=API_GATEWAY_URL=http://localhost:3000/api/v1 \
  --dart-define=CATALOG_SERVICE_URL=http://localhost:3002/api/v1
```

#### 3. Dispositivo físico (misma red Wi-Fi / LAN)

Reemplaza `192.168.1.X` con la dirección IP local de tu computador en la red Wi-Fi (asegúrate de que los puertos 3000 y 3002 no estén bloqueados por el firewall):

```bash
flutter run -d <device-id> \
  --dart-define=API_GATEWAY_URL=http://192.168.1.50:3000/api/v1 \
  --dart-define=CATALOG_SERVICE_URL=http://192.168.1.50:3002/api/v1
```

#### 4. Modo demostración offline (sin Backend)

Si el backend o PostgreSQL no están disponibles, puedes ejecutar la app con autenticación simulada:

```bash
flutter run --dart-define=AUTH_DEMO_MODE=true
```

## Comandos básicos de desarrollo

### Análisis estático y formato

Antes de enviar cambios o abrir un Pull Request, comprueba el formato y el linter:

```bash
# Aplicar formato automático a código y pruebas
dart format lib test

# Validar formato sin modificar archivos (falla si hay desalineación)
dart format --output=none --set-exit-if-changed lib test

# Ejecutar el analizador estático oficial
flutter analyze
```

La línea base inicial del análisis estático y su entorno reproducible están registrados en
[`docs/mobile/validacion-flutter-analyze.md`](../docs/mobile/validacion-flutter-analyze.md).

### Pruebas automatizadas

Las pruebas están organizadas en `test/` siguiendo la estructura de `lib/`.
Los recorridos que abarcan varias pantallas se ubican en `test/navigation/` y
los recursos compartidos para pruebas en `test/helpers/`.

`test/helpers/test_harness.dart` ofrece tres formas de montar escenarios con un
tamaño móvil reproducible de 390 × 844:

- `pumpAppUnderTest` para probar la aplicación completa con su configuración.
- `pumpWidgetUnderTest` para un widget dentro de Material y Riverpod.
- `pumpRouterUnderTest` para rutas aisladas con `GoRouter`.

Los providers que normalmente consultan servicios externos deben reemplazarse
mediante `ProviderScope.overrides`. Así, las pruebas no dependen del Backend ni
de Internet y siguen verificando la interfaz y la navegación reales.

Desde `mobile/` se puede ejecutar toda la batería o archivos específicos:

```bash
# Ejecutar todas las pruebas unitarias y de widgets
flutter test

# Ejecutar pruebas individuales
flutter test test/widget_test.dart
flutter test test/navigation/app_navigation_test.dart
flutter test test/features/auth/presentation/login_dio_test.dart

# Generar reporte de cobertura
flutter test --coverage
```

### Limpieza y mantenimiento del proyecto

Si experimentas problemas con paquetes o artefactos de compilación obsoletos:

```bash
flutter clean
flutter pub get
```

Si Android informa que faltan licencias del SDK:

```bash
flutter doctor --android-licenses
flutter doctor
```

## Documentación relacionada

- [Soporte de integración con Backend](../docs/mobile/integracion-api-mobile.md) — endpoints disponibles, modelos, contratos y notas técnicas.
- [Estructura del proyecto Mobile](../docs/mobile/estructura-proyecto-mobile.md) — convención de carpetas por capas y features.
- [Tema visual y diseño](../docs/mobile/tema-visual.md) — paleta de colores institucional, tipografía y componentes base.
- [Puertos y ejecución local del Backend](../backend/README.md) — instrucciones para levantar Gateway, Auth y Catalog.

