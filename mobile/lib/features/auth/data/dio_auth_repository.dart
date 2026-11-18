import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../models/user_model.dart';
import 'auth_repository.dart';
import 'models/login_request_model.dart';
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
      final intercepted = error.error;
      if (intercepted is ApiException) throw intercepted;
      throw ApiException.fromDioException(error);
    } on ApiException {
      rethrow;
    } on Object {
      await _cancel(generation);
      throw ApiException(
        message: 'No se pudo establecer una sesión válida y segura.',
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
      if (error.error is ApiException) throw error.error! as ApiException;
      throw ApiException.fromDioException(error);
    } on Object {
      throw ApiException(message: 'El servidor devolvió un registro inválido.');
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
