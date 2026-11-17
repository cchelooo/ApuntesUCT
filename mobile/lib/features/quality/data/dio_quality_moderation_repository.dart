import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/pending_moderation_item.dart';
import '../domain/repositories/quality_moderation_repository.dart';
import 'models/quality_moderation_queue_dto.dart';

/// Implementación HTTP de [QualityModerationRepository] vía API Gateway.
///
/// Consume la ruta privada de Quality (`GET /quality/moderation/pending`)
/// deserializando mediante el DTO privado [QualityModerationPageDto].
class DioQualityModerationRepository implements QualityModerationRepository {
  DioQualityModerationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PendingModerationPage> listPendingModeration({
    int page = 1,
    int pageSize = 10,
  }) async {
    if (page < 1 ||
        pageSize < 1 ||
        pageSize > 100 ||
        page > 2147483647 ||
        (page - 1) * pageSize > 2147483647) {
      throw ArgumentError('Paginación fuera de los límites del contrato.');
    }

    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/quality/moderation/pending',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException(
          'La respuesta de Quality no es un objeto JSON.',
        );
      }
      return QualityModerationPageDto.fromJson(data).toDomain();
    } on DioException catch (error) {
      final intercepted = error.error;
      if (intercepted is ApiException) throw intercepted;
      throw ApiException.fromDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        message: 'Quality devolvió una respuesta de moderación inválida.',
        data: error,
      );
    }
  }
}
