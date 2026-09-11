import 'api_exception.dart';

/// Convierte cualquier error en un mensaje mostrable al usuario.
///
/// La app convive con dos orígenes de error: la API real, que ya entrega
/// [ApiException] con un mensaje redactado, y el repositorio mock, que lanza
/// `Exception` genéricas. Sin esta función la UI mostraría literalmente
/// "Exception: Credenciales invalidas" con el prefijo de Dart a la vista.
String errorMessage(Object error) {
  if (error is ApiException) return error.message;

  if (error is Exception) {
    final text = error.toString();
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }

  return 'Ocurrió un error inesperado.';
}

/// Indica si el error es un registro exitoso sin sesión iniciada.
///
/// La UI usa esto para no mostrar un banner rojo cuando el backend creó la
/// cuenta pero exige que el usuario inicie sesión manualmente.
bool isRegistrationSuccess(Object error) =>
    error is RequiresVerificationException;
