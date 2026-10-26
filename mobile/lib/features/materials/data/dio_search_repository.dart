import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/material_page.dart';
import '../domain/models/material_requests.dart';
import '../domain/repositories/search_repository.dart';

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
    final cleanText = query.text.trim();
    final queryParams = <String, dynamic>{
      if (cleanText.isNotEmpty) 'q': cleanText,
      if (query.subjectId != null && query.subjectId!.isNotEmpty)
        'subjectId': query.subjectId,
      if (query.careerId != null && query.careerId!.isNotEmpty)
        'careerId': query.careerId,
      if (query.universityId != null && query.universityId!.isNotEmpty)
        'universityId': query.universityId,
      if (query.type != null && query.type!.isNotEmpty) 'type': query.type,
      if (page != 1) 'page': page,
      if (pageSize != 10) 'pageSize': pageSize,
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
            message == stubMessage ||
            message.contains('Semana 3') ||
            (data['results'] is List &&
                (data['results'] as List).isEmpty &&
                data['total'] == 0 &&
                message.isNotEmpty);

        if (isStubResponse) {
          throw SearchContractPendingException(
            message: message.isNotEmpty ? message : stubMessage,
            data: data,
          );
        }

        if (data.containsKey('results') && !data.containsKey('items')) {
          final mapped = Map<String, dynamic>.from(data);
          mapped['items'] = data['results'] ?? [];
          mapped['page'] = page;
          mapped['pageSize'] = pageSize;
          return MaterialPage.fromJson(mapped);
        }
        return MaterialPage.fromJson(data);
      }

      return MaterialPage(
        items: const [],
        page: page,
        pageSize: pageSize,
        total: 0,
      );
    } on DioException catch (error) {
      final intercepted = error.error;
      if (intercepted is ApiException) throw intercepted;
      throw ApiException.fromDioException(error);
    } catch (_) {
      rethrow;
    }
  }
}
