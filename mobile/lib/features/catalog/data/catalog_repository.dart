import 'package:apuntesuct_mobile/core/config/api_config.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/catalog_item.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final catalogApiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: ApiConfig.catalogBaseUrl);
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final apiClient = ref.watch(catalogApiClientProvider);
  return CatalogRepository(apiClient);
});

class CatalogRepository {
  final ApiClient _apiClient;

  CatalogRepository(this._apiClient);

  Future<List<CatalogItem>> getCatalog({String? search}) async {
    try {
      final response = await _apiClient.dio.get('/catalog');
      final dynamic rawData = response.data;

      final List<CatalogItem> items = [];

      // Parseo del árbol: Universidad -> Carreras -> Asignaturas
      if (rawData is List) {
        for (final uni in rawData) {
          if (uni is Map<String, dynamic>) {
            final uniName = uni['name'] as String? ?? 'UCT';
            final careers = uni['careers'] as List<dynamic>? ?? [];

            if (careers.isEmpty) {
              items.add(CatalogItem.fromJson(uni));
            } else {
              for (final car in careers) {
                if (car is Map<String, dynamic>) {
                  final carName = car['name'] as String? ?? '';
                  final subjects = car['subjects'] as List<dynamic>? ?? [];

                  for (final sub in subjects) {
                    if (sub is Map<String, dynamic>) {
                      items.add(
                        CatalogItem(
                          id: sub['id']?.toString() ?? '',
                          title: sub['name'] as String? ?? 'Asignatura',
                          author: uniName,
                          subject: carName.isNotEmpty ? carName : 'General',
                          description: sub['description'] as String?,
                        ),
                      );
                    }
                  }
                }
              }
            }
          }
        }
      } else if (rawData is Map<String, dynamic>) {
        final list = rawData['data'] as List<dynamic>? ?? [];
        for (final el in list) {
          if (el is Map<String, dynamic>) {
            items.add(CatalogItem.fromJson(el));
          }
        }
      }

      // Filtrado en memoria/cliente
      if (search != null && search.trim().isNotEmpty) {
        final query = search.trim().toLowerCase();
        return items.where((item) {
          return item.title.toLowerCase().contains(query) ||
              item.author.toLowerCase().contains(query) ||
              item.subject.toLowerCase().contains(query);
        }).toList();
      }

      return items;
    } on DioException {
      rethrow;
    } catch (_) {
      return [];
    }
  }
}
