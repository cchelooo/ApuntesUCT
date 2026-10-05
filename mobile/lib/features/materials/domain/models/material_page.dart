import 'material_json.dart';
import 'material_summary.dart';

/// Página del dominio; el adaptador traduce la envoltura paginada de OpenAPI.
class MaterialPage {
  final List<MaterialSummary> items;
  final int page;
  final int pageSize;
  final int total;

  MaterialPage({
    required List<MaterialSummary> items,
    required this.page,
    required this.pageSize,
    required this.total,
  }) : items = List.unmodifiable(items) {
    if (page < 1 ||
        pageSize < 1 ||
        total < 0 ||
        items.length > pageSize ||
        items.length > total) {
      throw ArgumentError('Metadatos de paginación inválidos.');
    }
  }

  int get totalPages => (total / pageSize).ceil();
  bool get hasNextPage => page < totalPages;

  factory MaterialPage.fromJson(Map<String, dynamic> json) {
    final page = MaterialJson.integer(json, 'page', min: 1);
    final pageSize = MaterialJson.integer(json, 'pageSize', min: 1);
    final total = MaterialJson.integer(json, 'total');
    if (page == null ||
        pageSize == null ||
        total == null ||
        json['items'] is! List) {
      throw const FormatException('Faltan los items o metadatos de la página.');
    }
    final items = MaterialJson.list(
      json,
      'items',
      (item) => MaterialSummary.fromJson(MaterialJson.object(item)),
    );
    if (items.length > pageSize || items.length > total) {
      throw const FormatException(
        'Los items no coinciden con los metadatos de página.',
      );
    }
    return MaterialPage(
      items: items,
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'page': page,
    'pageSize': pageSize,
    'total': total,
  };
}
