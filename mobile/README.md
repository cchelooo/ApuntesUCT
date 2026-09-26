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

## Verificar el proyecto

Antes de subir cambios, ejecuta:

```bash
flutter analyze
flutter test
```

## Pruebas automatizadas

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

Desde `mobile/` se puede ejecutar toda la batería o un archivo específico:

```bash
flutter test
flutter test test/widget_test.dart
flutter test test/navigation/register_navigation_test.dart
flutter test --coverage
```

Antes de entregar cambios de Mobile también se debe comprobar el formato y el
análisis estático:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
```

La línea base inicial del análisis estático y su entorno reproducible están
registrados en
[`docs/mobile/validacion-flutter-analyze.md`](../docs/mobile/validacion-flutter-analyze.md).

Si Android informa que faltan licencias del SDK, acéptalas y vuelve a comprobar el entorno:

```bash
flutter doctor --android-licenses
flutter doctor
```
