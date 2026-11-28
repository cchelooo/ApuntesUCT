import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../models/user_model.dart';
import 'auth_repository.dart';
import 'models/login_request_model.dart';
import 'models/password_recovery_models.dart';
import 'models/register_request_model.dart';

/// Auth through Gateway. No production operation falls back to a mock.
class DioAuthRepository implements AuthRepository {
  // Second argument retained for existing explicit test injections; never used.
  DioAuthRepository(this._apiClient, [AuthRepository? unusedFallback]);
  final ApiClient _apiClient;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final generation = _apiClient.session.beginLogin();
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/login',
        data: LoginRequestModel(email: email, password: password).toJson(),
      );
      if (response.data is! Map) throw const FormatException();
      final session = AuthSession.fromLogin(
        Map<String, dynamic>.from(response.data as Map),
        _apiClient.session.now(),
      );
      if (!await _apiClient.session.accept(session, generation)) {
        throw ApiException(
          message: 'El acceso fue cancelado. Inicia sesión nuevamente.',
        );
      }
      return session.user;
    } on DioException catch (error) {
      await _cancel(generation);
      throw _mapLoginDioError(error);
    } on ApiException {
      rethrow;
    } on Object {
      await _cancel(generation);
      throw ApiException(
        message: 'No se pudo establecer una sesión válida y segura.',
      );
    }
  }

  ApiException _mapLoginDioError(DioException error) {
    final intercepted = error.error is ApiException
        ? error.error! as ApiException
        : ApiException.fromDioException(error);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message:
              'Tiempo de espera agotado al conectar con el servidor. Verifica tu conexión e inténtalo nuevamente.',
          statusCode: intercepted.statusCode,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message:
              'No se pudo establecer conexión con el servidor. Verifica tu red o que el servidor esté activo.',
          statusCode: intercepted.statusCode,
        );
      case DioExceptionType.badResponse:
        final statusCode =
            error.response?.statusCode ?? intercepted.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return ApiException(
            message:
                'Credenciales inválidas. Verifica tu correo institucional y contraseña.',
            statusCode: statusCode,
          );
        }
        if (statusCode == 400) {
          return ApiException(
            message:
                'Los datos ingresados no son válidos. Revisa tu correo institucional y contraseña.',
            statusCode: statusCode,
          );
        }
        if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
          return ApiException(
            message:
                'El servicio de autenticación no está disponible en este momento. Intenta nuevamente más tarde.',
            statusCode: statusCode,
          );
        }
        if (statusCode != null && statusCode >= 500) {
          return ApiException(
            message:
                'No fue posible iniciar sesión por un problema en el servidor. Intenta nuevamente más tarde.',
            statusCode: statusCode,
          );
        }
        return ApiException(
          message:
              'No fue posible iniciar sesión. Intenta nuevamente más tarde.',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'La petición fue cancelada.',
          statusCode: intercepted.statusCode,
        );
      default:
        return ApiException(
          message:
              'No se pudo establecer conexión segura con el servidor. Verifica tu red e inténtalo nuevamente.',
          statusCode: intercepted.statusCode,
        );
    }
  }

  Future<void> _cancel(int generation) async {
    try {
      await _apiClient.session.cancelLogin(generation);
    } on Object {
      /* Memory is already cleared; do not expose storage details. */
    }
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/register',
        data: RegisterRequestModel(
          name: name,
          email: email,
          password: password,
        ).toJson(),
      );
      final data = response.data;
      if (data is! Map || data['user'] is! Map) throw const FormatException();
      return UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    } on DioException catch (error) {
      throw _mapRegisterDioError(error);
    } on ApiException {
      rethrow;
    } on Object {
      throw ApiException(message: 'El servidor devolvió un registro inválido.');
    }
  }

  ApiException _mapRegisterDioError(DioException error) {
    final intercepted = error.error is ApiException
        ? error.error! as ApiException
        : ApiException.fromDioException(error);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message:
              'Tiempo de espera agotado al conectar con el servidor. Verifica tu conexión e inténtalo nuevamente.',
          statusCode: intercepted.statusCode,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message:
              'No se pudo establecer conexión con el servidor. Verifica tu red o que el servidor esté activo.',
          statusCode: intercepted.statusCode,
        );
      case DioExceptionType.badResponse:
        final statusCode =
            error.response?.statusCode ?? intercepted.statusCode;
        if (statusCode == 409) {
          return ApiException(
            message:
                'El correo institucional ya está registrado. Inicia sesión o recupera tu contraseña.',
            statusCode: statusCode,
          );
        }
        if (statusCode == 400) {
          return ApiException(
            message:
                'Los datos ingresados no son válidos. Revisa tu nombre, correo institucional y contraseña.',
            statusCode: statusCode,
          );
        }
        if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
          return ApiException(
            message:
                'El servicio de autenticación no está disponible en este momento. Intenta nuevamente más tarde.',
            statusCode: statusCode,
          );
        }
        if (statusCode != null && statusCode >= 500) {
          return ApiException(
            message:
                'No fue posible completar el registro por un problema en el servidor. Intenta nuevamente más tarde.',
            statusCode: statusCode,
          );
        }
        return ApiException(
          message:
              'No fue posible completar el registro. Intenta nuevamente más tarde.',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'La petición fue cancelada.',
          statusCode: intercepted.statusCode,
        );
      default:
        return ApiException(
          message:
              'No se pudo establecer conexión segura con el servidor. Verifica tu red e inténtalo nuevamente.',
          statusCode: intercepted.statusCode,
        );
    }
  }

  @override
  Future<String> requestPasswordRecovery({required String email}) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/forgot-password',
        data: ForgotPasswordRequestModel(email: email).toJson(),
      );
      final data = response.data;
      if (data is Map &&
          data['message'] is String &&
          (data['message'] as String).trim().isNotEmpty) {
        return (data['message'] as String).trim();
      }
      return 'Si el correo corresponde a una cuenta habilitada, recibirás instrucciones para recuperar tu contraseña.';
    } on DioException catch (error) {
      throw _mapForgotPasswordDioError(error);
    } on ApiException {
      rethrow;
    } on Object {
      throw ApiException(
        message:
            'No fue posible procesar la solicitud de recuperación en este momento.',
      );
    }
  }

  ApiException _mapForgotPasswordDioError(DioException error) {
    final intercepted = error.error is ApiException
        ? error.error! as ApiException
        : ApiException.fromDioException(error);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message:
              'Tiempo de espera agotado al conectar con el servidor. Verifica tu conexión e inténtalo nuevamente.',
          statusCode: intercepted.statusCode,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message:
              'No se pudo establecer conexión con el servidor. Verifica tu red o que el servidor esté activo.',
          statusCode: intercepted.statusCode,
        );
      case DioExceptionType.badResponse:
        final statusCode =
            error.response?.statusCode ?? intercepted.statusCode;
        if (statusCode == 400) {
          return ApiException(
            message:
                'El correo ingresado no es válido. Verifica tu correo institucional.',
            statusCode: statusCode,
          );
        }
        if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
          return ApiException(
            message:
                'El servicio de recuperación o envío de correo no está disponible en este momento. La integración permanece pendiente hasta que el servicio esté activo.',
            statusCode: statusCode,
          );
        }
        if (statusCode != null && statusCode >= 500) {
          return ApiException(
            message:
                'No fue posible solicitar la recuperación por un problema en el servidor. Intenta nuevamente más tarde.',
            statusCode: statusCode,
          );
        }
        return ApiException(
          message:
              'No fue posible solicitar la recuperación de contraseña. Intenta nuevamente más tarde.',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'La petición fue cancelada.',
          statusCode: intercepted.statusCode,
        );
      default:
        return ApiException(
          message:
              'No se pudo establecer conexión segura con el servidor. Verifica tu red e inténtalo nuevamente.',
          statusCode: intercepted.statusCode,
        );
    }
  }

  @override
  Future<String> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/reset-password',
        data: ResetPasswordRequestModel(
          token: token,
          password: password,
        ).toJson(),
      );
      final data = response.data;
      if (data is Map &&
          data['message'] is String &&
          (data['message'] as String).trim().isNotEmpty) {
        return (data['message'] as String).trim();
      }
      return 'Contraseña restablecida correctamente.';
    } on DioException catch (error) {
      throw _mapResetPasswordDioError(error);
    } on ApiException {
      rethrow;
    } on Object {
      throw ApiException(
        message: 'No fue posible restablecer la contraseña en este momento.',
      );
    }
  }

  ApiException _mapResetPasswordDioError(DioException error) {
    final intercepted = error.error is ApiException
        ? error.error! as ApiException
        : ApiException.fromDioException(error);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message:
              'Tiempo de espera agotado al conectar con el servidor. Verifica tu conexión e inténtalo nuevamente.',
          statusCode: intercepted.statusCode,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message:
              'No se pudo establecer conexión con el servidor. Verifica tu red o que el servidor esté activo.',
          statusCode: intercepted.statusCode,
        );
      case DioExceptionType.badResponse:
        final statusCode =
            error.response?.statusCode ?? intercepted.statusCode;
        if (statusCode == 400) {
          final backendMsg = intercepted.message.toLowerCase();
          if (backendMsg.contains('token') ||
              backendMsg.contains('expirado') ||
              backendMsg.contains('vencido')) {
            return ApiException(
              message:
                  'El código o enlace de recuperación es inválido, ya fue utilizado o ha expirado. Solicita uno nuevo para continuar.',
              statusCode: statusCode,
            );
          }
          return ApiException(
            message:
                'Los datos ingresados no son válidos o el código de recuperación ha expirado. Verifica la contraseña o solicita un nuevo código.',
            statusCode: statusCode,
          );
        }
        if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
          return ApiException(
            message:
                'El servicio de recuperación no está disponible en este momento. Intenta nuevamente más tarde.',
            statusCode: statusCode,
          );
        }
        if (statusCode != null && statusCode >= 500) {
          return ApiException(
            message:
                'No fue posible restablecer la contraseña por un problema en el servidor. Intenta nuevamente más tarde.',
            statusCode: statusCode,
          );
        }
        return ApiException(
          message:
              'No fue posible restablecer la contraseña. Intenta nuevamente más tarde.',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'La petición fue cancelada.',
          statusCode: intercepted.statusCode,
        );
      default:
        return ApiException(
          message:
              'No se pudo establecer conexión segura con el servidor. Verifica tu red e inténtalo nuevamente.',
          statusCode: intercepted.statusCode,
        );
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    await _apiClient.session.restore();
    final user = _apiClient.session.current?.user;
    if (user == null) {
      throw ApiException(
        message: 'Inicia sesión para continuar.',
        statusCode: 401,
      );
    }
    return user;
  }

  /// Auth has no remote logout/refresh endpoint in the published contract.
  @override
  Future<void> logout() => _apiClient.session.clear();
}
