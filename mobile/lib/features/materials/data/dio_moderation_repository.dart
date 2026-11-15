import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/material_page.dart';
import '../domain/repositories/moderation_repository.dart';

/// Implementación HTTP de [ModerationRepository] a través del API Gateway.
///
/// Consume el endpoint privado de materiales pendientes de revisión
/// (`GET /materials/pending`) utilizando la sesión autorizada en [ApiClient].
class DioModerationRepository implements ModerationRepository {
  DioModerationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<MaterialPage> listPending({int page = 1, int pageSize = 10}) async {
    if (page < 1 ||
        pageSize < 1 ||
        pageSize > 100 ||
        page > 2147483647 ||
        (page - 1) * pageSize > 2147483647) {
      throw ArgumentError('Paginación fuera de los límites del contrato.');
    }

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/materials/pending',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException(
          'La respuesta de la cola de moderación no es un objeto JSON.',
        );
      }
      return MaterialPage.fromJson(data);
    } on DioException catch (error) {
      final intercepted = error.error;
      if (intercepted is ApiException) throw intercepted;
      throw ApiException.fromDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        message: 'El servidor devolvió una cola de revisión inválida.',
        data: error,
      );
    }
  }
}
