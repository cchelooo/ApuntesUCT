import '../../../materials/domain/models/material_summary.dart';
import 'favorite_model.dart';
import 'quality_json.dart';

/// Elemento del listado de favoritos personales para la interfaz visual.
///
/// Combina los metadatos de [Favorite] devueltos por Quality Service con los
/// datos de presentación del material requeridos por [MaterialSummaryCard].
class FavoriteItem {
  final String id;
  final String materialId;
  final String title;
  final String subjectName;
  final String careerName;
  final String authorName;
  final int? academicYear;
  final String fileType;
  final double rating;
  final int downloadCount;
  final DateTime createdAt;
  final bool available;

  const FavoriteItem({
    required this.id,
    required this.materialId,
    required this.title,
    required this.subjectName,
    required this.careerName,
    required this.authorName,
    this.academicYear,
    this.fileType = 'PDF',
    this.rating = 0.0,
    this.downloadCount = 0,
    required this.createdAt,
    this.available = true,
  });

  /// Crea un elemento a partir de un [Favorite] y datos de resumen del material.
  factory FavoriteItem.fromFavorite({
    required Favorite favorite,
    required String title,
    String subjectName = 'General',
    String careerName = 'UCT',
    String authorName = 'Anónimo',
    int? academicYear,
    String fileType = 'PDF',
    double rating = 0.0,
    int downloadCount = 0,
  }) {
    return FavoriteItem(
      id: favorite.id,
      materialId: favorite.materialId,
      title: title,
      subjectName: subjectName,
      careerName: careerName,
      authorName: authorName,
      academicYear: academicYear,
      fileType: fileType,
      rating: rating,
      downloadCount: downloadCount,
      createdAt: favorite.createdAt,
      available: favorite.available,
    );
  }

  /// Deserialización desde JSON compuesto (compatible con previews y respuestas API).
  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: QualityJson.requiredUuid(json, 'id'),
      materialId: QualityJson.requiredUuid(json, 'materialId'),
      title: QualityJson.requiredText(json, 'title'),
      subjectName: json['subjectName'] as String? ?? 'General',
      careerName: json['careerName'] as String? ?? 'UCT',
      authorName: json['authorName'] as String? ?? 'Anónimo',
      academicYear: json['academicYear'] is int
          ? json['academicYear'] as int
          : (json['academicYear'] is num ? (json['academicYear'] as num).toInt() : null),
      fileType: json['fileType'] as String? ?? 'PDF',
      rating: json['rating'] is num ? (json['rating'] as num).toDouble() : 0.0,
      downloadCount: json['downloadCount'] is int
          ? json['downloadCount'] as int
          : (json['downloadCount'] is num ? (json['downloadCount'] as num).toInt() : 0),
      createdAt: QualityJson.requiredTimestamp(json, 'createdAt'),
      available: json['available'] is bool ? json['available'] as bool : true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'materialId': materialId,
    'title': title,
    'subjectName': subjectName,
    'careerName': careerName,
    'authorName': authorName,
    if (academicYear != null) 'academicYear': academicYear,
    'fileType': fileType,
    'rating': rating,
    'downloadCount': downloadCount,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'available': available,
  };

  /// Convierte a [MaterialSummary] para reutilizar [MaterialSummaryCard] y la navegación existente.
  MaterialSummary toMaterialSummary() {
    return MaterialSummary(
      id: materialId,
      title: title,
      subjectName: subjectName,
      careerName: careerName,
      authorName: authorName,
      academicYear: academicYear,
      fileType: fileType,
      rating: rating,
      downloadCount: downloadCount,
      status: available ? 'APPROVED' : 'WITHDRAWN',
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          materialId == other.materialId &&
          available == other.available;

  @override
  int get hashCode => Object.hash(id, materialId, available);
}

/// Datos explícitos de preparación para la vista previa de Favoritos (S3-M09).
///
/// Estos fixtures permiten verificar los estados visuales sin simular una
/// integración real terminada con Backend (Criterio 4).
class FavoritesFixtures {
  static const String preparationNotice =
      'Vista previa en preparación (Sprint 3 / S3-M09). Integración con API real en Semana 3.';

  static final List<FavoriteItem> defaultFavorites = [
    FavoriteItem(
      id: 'f0000001-0000-4000-8000-000000000001',
      materialId: 'm0000001-0000-4000-8000-000000000001',
      title: 'Guía Completa de Cálculo I - Derivadas e Integrales',
      subjectName: 'Cálculo I',
      careerName: 'Ingeniería Civil Informática',
      authorName: 'Prof. Carlos Gómez',
      academicYear: 2024,
      fileType: 'PDF',
      rating: 4.8,
      downloadCount: 142,
      createdAt: DateTime.utc(2026, 11, 1, 10, 30),
      available: true,
    ),
    FavoriteItem(
      id: 'f0000002-0000-4000-8000-000000000002',
      materialId: 'm0000002-0000-4000-8000-000000000002',
      title: 'Resumen Estructuras de Datos y Algoritmos en Dart',
      subjectName: 'Estructuras de Datos',
      careerName: 'Ingeniería Civil Informática',
      authorName: 'Ana Morales',
      academicYear: 2024,
      fileType: 'PDF',
      rating: 4.5,
      downloadCount: 89,
      createdAt: DateTime.utc(2026, 11, 3, 14, 15),
      available: true,
    ),
    FavoriteItem(
      id: 'f0000003-0000-4000-8000-000000000003',
      materialId: 'm0000003-0000-4000-8000-000000000003',
      title: 'Apuntes de Álgebra Lineal - Espacios Vectoriales',
      subjectName: 'Álgebra Lineal',
      careerName: 'Plan Común Ingeniería',
      authorName: 'Roberto Fuentes',
      academicYear: 2023,
      fileType: 'PDF',
      rating: 4.2,
      downloadCount: 65,
      createdAt: DateTime.utc(2026, 11, 5, 9, 0),
      available: true,
    ),
  ];
}
