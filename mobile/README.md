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

Si Android informa que faltan licencias del SDK, acéptalas y vuelve a comprobar el entorno:

```bash
flutter doctor --android-licenses
flutter doctor
```
