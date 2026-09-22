import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apuntesuct_mobile/features/catalog/data/catalog_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/catalog_item.dart';

/// Notifier para manejar el término de búsqueda en el catálogo.
class CatalogSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Provider que almacena el texto actual del buscador.
final catalogSearchQueryProvider =
    NotifierProvider<CatalogSearchQueryNotifier, String>(
      CatalogSearchQueryNotifier.new,
    );

/// Provider asíncrono que consulta el repositorio según la búsqueda activa.
final catalogListProvider = FutureProvider<List<CatalogItem>>((ref) async {
  final repository = ref.watch(catalogRepositoryProvider);
  final query = ref.watch(catalogSearchQueryProvider);

  return repository.getCatalog(search: query.isEmpty ? null : query);
});
