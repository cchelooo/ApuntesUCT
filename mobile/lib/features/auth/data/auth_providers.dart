import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'auth_api.dart';
import 'mock_auth_repository.dart' show AuthRepository, authRepositoryProvider;
import 'remote_auth_repository.dart';

/// Cliente HTTP compartido por toda la aplicación.
///
/// Se declara una sola vez para que el `TokenStore` sea el mismo en cada
/// petición: si cada feature creara su propio [ApiClient], la sesión abierta en
/// Login no acompañaría a las llamadas del catálogo.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Acceso tipado a los endpoints de autenticación.
final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});

/// Repositorio de autenticación respaldado por la API real.
final remoteAuthRepositoryProvider = Provider<AuthRepository>((ref) {
  return RemoteAuthRepository(ref.watch(authApiProvider));
});

/// Override que hace que toda la app consuma la API real en lugar del mock.
///
/// Se aplica en `main()` cuando se compila con `--dart-define=USE_REMOTE_API=true`.
/// Es un override y no un cambio del provider original para que el mock siga
/// siendo el camino por defecto mientras Auth Service no esté desplegado, y
/// para que las pruebas puedan elegir el repositorio que necesiten.
final useRemoteAuthOverride = authRepositoryProvider.overrideWith(
  (ref) => RemoteAuthRepository(ref.watch(authApiProvider)),
);
