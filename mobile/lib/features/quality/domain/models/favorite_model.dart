import 'quality_json.dart';

/// Representación contractual de un material guardado en favoritos propios (`FavoriteDto`).
///
/// Cumple estrictamente con el esquema publicado en `quality.openapi.json`:
/// - `id`: Identificador único del favorito (UUID).
/// - `materialId`: Identificador del material asociado (UUID).
/// - `createdAt`: Marca de tiempo de registro (ISO 8601 UTC).
/// - `available`: Disponibilidad pública del material (false si fue retirado u oculto).
class Favorite {
  final String id;
  final String materialId;
  final DateTime createdAt;
  final bool available;

  const Favorite({
    required this.id,
    required this.materialId,
    required this.createdAt,
    required this.available,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: QualityJson.requiredUuid(json, 'id'),
      materialId: QualityJson.requiredUuid(json, 'materialId'),
      createdAt: QualityJson.requiredTimestamp(json, 'createdAt'),
      available: QualityJson.requiredBoolean(json, 'available'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'materialId': materialId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'available': available,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Favorite &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          materialId == other.materialId &&
          createdAt == other.createdAt &&
          available == other.available;

  @override
  int get hashCode => Object.hash(id, materialId, createdAt, available);

  @override
  String toString() =>
      'Favorite(id: $id, materialId: $materialId, available: $available, createdAt: $createdAt)';
}

/// Respuesta paginada de favoritos personales (`FavoritePageDto`).
class FavoritePage {
  final List<Favorite> items;
  final int page;
  final int pageSize;
  final int total;

  const FavoritePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  int get totalPages => (total / pageSize).ceil();
  bool get hasNextPage => page < totalPages;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  factory FavoritePage.fromJson(Map<String, dynamic> json) {
    final page = QualityJson.requiredInteger(json, 'page', min: 1);
    final pageSize = QualityJson.requiredInteger(json, 'pageSize', min: 1, max: 100);
    final total = QualityJson.requiredInteger(json, 'total', min: 0);
    final items = QualityJson.list(
      json,
      'items',
      (item) => Favorite.fromJson(QualityJson.object(item)),
    );

    return FavoritePage(
      items: List.unmodifiable(items),
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((f) => f.toJson()).toList(),
    'page': page,
    'pageSize': pageSize,
    'total': total,
  };
}
