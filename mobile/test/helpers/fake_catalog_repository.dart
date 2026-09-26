import 'package:apuntesuct_mobile/features/catalog/data/catalog_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/catalog_item.dart';

/// Repositorio determinista para probar pantallas sin consultar el Backend.
class FakeCatalogRepository implements CatalogRepository {
  const FakeCatalogRepository({this.items = const []});

  final List<CatalogItem> items;

  @override
  Future<List<CatalogItem>> getCatalog({String? search}) async {
    if (search == null || search.trim().isEmpty) {
      return items;
    }

    final query = search.trim().toLowerCase();
    return items.where((item) {
      return item.title.toLowerCase().contains(query) ||
          item.author.toLowerCase().contains(query) ||
          item.subject.toLowerCase().contains(query);
    }).toList();
  }
}
