import '../models/material_page.dart';

/// Lectura disponible en GET /materials, independiente de Search y de Dio.
abstract interface class MaterialListingRepository {
  Future<MaterialPage> list({int page = 1, int pageSize = 10});
}
