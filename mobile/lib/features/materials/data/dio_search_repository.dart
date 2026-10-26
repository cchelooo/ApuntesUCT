import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final apiClient = ref.watch(apiclientProvider);
  return DioSearchRepository(apiClient);
});

class DioSearchRepository implements SearchRepository {
  final ApiClient _apiClient;

  DioSearchRepository(this._apiClient);

  @override
  Future<MaterialPage> search(
    MaterialSearchQuery query, {
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        if (query.text.trim().isNotEmpty) 'q': query.text.trim(),
        if (query.subjectId != null && query.subjectId!.isNotEmpty)
          'subjectId': query.subjectId,
        if (query.careerId != null && query.careerId!.isNotEmpty)
          'careerId': query.careerId,
        if (query.universityId != null && query.universityId!.isNotEmpty)
          'universityId': query.universityId,
        if (query.type != null && query.type!.isNotEmpty) 'type': query.type,
      };

      final response = await _apiClient.dio.get(
        '/search',
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        // Soporte tanto para formato estándar MaterialPage ({items, page, ...})
        // como para stub de Search ({results, total, ...})
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
    } on DioException {
      rethrow;
    }
  }
}
