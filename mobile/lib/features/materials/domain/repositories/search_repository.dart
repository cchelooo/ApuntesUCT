import '../models/material_page.dart';
import '../models/material_requests.dart';

/// Search Service recibe texto y filtros; no modifica ni versiona materiales.
abstract interface class SearchRepository {
  Future<MaterialPage> search(
    MaterialSearchQuery query, {
    int page = 1,
    int pageSize = 10,
  });
}
