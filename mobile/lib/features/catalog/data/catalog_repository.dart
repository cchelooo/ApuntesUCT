import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/catalog_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final apiClient = ref.watch(
    apiclientProvider,
  ); // Ahora obtiene el ApiClient correctamente
  return CatalogRepository(apiClient);
});

class CatalogRepository {
  final ApiClient _apiClient; // <--- Cambiado de 'Dio' a 'ApiClient'

  CatalogRepository(this._apiClient);

  Future<List<CatalogItem>> getCatalog({String? search}) async {
    final queryParameters = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    // Usamos .dio para acceder al cliente HTTP configurado internamente
    final response = await _apiClient.dio.get(
      '/catalog',
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );

    final dynamic rawData = response.data;
    final List<dynamic> list;

    if (rawData is List) {
      list = rawData;
    } else if (rawData is Map<String, dynamic> && rawData['data'] is List) {
      list = rawData['data'] as List<dynamic>;
    } else if (rawData is Map<String, dynamic> && rawData['items'] is List) {
      list = rawData['items'] as List<dynamic>;
    } else {
      list = [];
    }

    return list
        .map((item) => CatalogItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
