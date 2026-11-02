import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/material_page.dart';
import '../domain/models/material_requests.dart';
import '../domain/repositories/search_repository.dart';
import 'search_response.dart';

/// Permite distinguir una integración pendiente de una búsqueda sin resultados.
class SearchContractPendingException extends ApiException {
  SearchContractPendingException({required super.message, super.data});
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final apiClient = ref.watch(apiclientProvider);
  return DioSearchRepository(apiClient);
});

class DioSearchRepository implements SearchRepository {
  DioSearchRepository(this._client);
  final ApiClient _client;

  static const stubMessage =
      'Search Service inicializado correctamente. '
      'Búsqueda desacoplada lista para Semana 3.';

  @override
  Future<MaterialPage> search(
    MaterialSearchQuery query, {
    int page = 1,
    int pageSize = 10,
    CancelToken? cancelToken,
  }) async {
    if (page < 1 || pageSize < 1 || pageSize > 100 || page > 2147483647) {
      throw ArgumentError('Paginación fuera de los límites de Search.');
    }
    final cleanText = query.text.trim();
    final queryParams = <String, dynamic>{
      if (cleanText.isNotEmpty) 'q': cleanText,
      for (final entry in <String, String?>{
        'universityId': query.universityId,
        'careerId': query.careerId,
        'subjectId': query.subjectId,
        'professorId': query.professorId,
        'type': query.type,
        'sortBy': query.sortBy,
        'order': query.order,
      }.entries)
        if (entry.value?.trim().isNotEmpty ?? false)
          entry.key: entry.value!.trim(),
      if (query.year != null) 'year': query.year,
      // El servidor usa 20 por defecto, mientras Mobile solicita 10.
      'page': page,
      'pageSize': pageSize,
    };

    try {
      final response = await _client.dio.get<dynamic>(
        '/search',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final message = data['message']?.toString() ?? '';
        final isStubResponse =
            message == stubMessage || message.contains('Semana 3');

        if (isStubResponse) {
          throw SearchContractPendingException(
            message: message.isNotEmpty ? message : stubMessage,
            data: data,
          );
        }
      }
      final result = searchPageFromResponse(data);
      if (result.page != page || result.pageSize != pageSize) {
        throw const FormatException(
          'La página de Search no corresponde a la solicitud.',
        );
      }
      return result;
    } on DioException catch (error) {
      final intercepted = error.error;
      if (intercepted is ApiException) throw intercepted;
      throw ApiException.fromDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        message: 'Search devolvió una respuesta inválida.',
        data: error,
      );
    }
  }
}
