import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../models/user_model.dart';
import 'auth_repository.dart';
import 'models/login_request_model.dart';
import 'models/login_response_model.dart';

/// Repositorio que consume Auth Service mediante el [ApiClient] compartido.
///
/// Por ahora Backend sólo expone el login mock a través del Gateway. Las demás
/// operaciones se delegan al repositorio de respaldo para no romper Registro y
/// Logout mientras sus endpoints continúan pendientes.
class DioAuthRepository implements AuthRepository {
  DioAuthRepository(this._apiClient, this._fallback);

  final ApiClient _apiClient;
  final AuthRepository _fallback;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final request = LoginRequestModel(email: email, password: password);
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/login',
        data: request.toJson(),
      );

      final data = response.data;
      if (data is! Map) {
        throw const FormatException(
          'La respuesta de login no es un objeto JSON.',
        );
      }

      try {
        return LoginResponseModel.fromJson(Map<String, dynamic>.from(data))
            .user;
      } on Object catch (error) {
        throw ApiException(
          message: 'El servidor devolvió una respuesta de login inválida.',
          data: error,
        );
      }
    } on DioException catch (error) {
      final interceptedError = error.error;
      if (interceptedError is ApiException) {
        throw interceptedError;
      }
      throw ApiException.fromDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        message: 'El servidor devolvió una respuesta de login inválida.',
        data: error,
      );
    }
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _fallback.register(name: name, email: email, password: password);
  }

  @override
  Future<UserModel> getCurrentUser() => _fallback.getCurrentUser();

  @override
  Future<void> logout() => _fallback.logout();
}
