import 'quality_json.dart';

/// Calificación individual emitida por un estudiante (`RatingDto`).
///
/// Contrato `quality.openapi.json`:
/// - `id`: UUID único del registro de calificación.
/// - `materialId`: UUID del material calificado.
/// - `userId`: UUID del autor de la calificación.
/// - `score`: Puntuación entera entre 1 y 5.
/// - `comment`: Comentario justificativo opcional (sin datos ficticios si es nulo).
/// - `createdAt` y `updatedAt`: Fechas UTC.
class Rating {
  final String id;
  final String materialId;
  final String userId;
  final int score;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Rating({
    required this.id,
    required this.materialId,
    required this.userId,
    required this.score,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(score >= 1 && score <= 5, 'Score debe estar entre 1 y 5');

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: QualityJson.requiredUuid(json, 'id'),
      materialId: QualityJson.requiredUuid(json, 'materialId'),
      userId: QualityJson.requiredUuid(json, 'userId'),
      score: QualityJson.requiredInteger(json, 'score', min: 1, max: 5),
      comment: QualityJson.text(json, 'comment'),
      createdAt: QualityJson.requiredTimestamp(json, 'createdAt'),
      updatedAt: QualityJson.requiredTimestamp(json, 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'materialId': materialId,
    'userId': userId,
    'score': score,
    if (comment != null) 'comment': comment,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Rating &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          materialId == other.materialId &&
          userId == other.userId &&
          score == other.score &&
          comment == other.comment &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    materialId,
    userId,
    score,
    comment,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Rating(id: $id, materialId: $materialId, userId: $userId, score: $score, comment: $comment)';
}

/// Resumen público consolidado de calificaciones de un material (`RatingSummaryDto`).
///
/// Cuando el material aún no posee calificaciones (`count == 0`), el contrato
/// devuelve `average: null`, sin sustituirlo por cero.
class RatingSummary {
  final String materialId;
  final int count;
  final double? average;

  const RatingSummary({
    required this.materialId,
    required this.count,
    this.average,
  }) : assert(count >= 0, 'Count no puede ser negativo'),
       assert(
         average == null || (average >= 1.0 && average <= 5.0),
         'Average debe ser null o estar entre 1.0 y 5.0',
       ),
       assert(
         count > 0 || average == null,
         'Cuando count es 0, average debe ser null',
       ),
       assert(
         count == 0 || average != null,
         'Cuando count > 0, average no puede ser null',
       );

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    final count = QualityJson.requiredInteger(json, 'count', min: 0);
    final average = QualityJson.number(json, 'average', min: 1.0, max: 5.0);
    if (count == 0 && average != null) {
      throw const FormatException(
        'Cuando count es 0, average debe ser null sin sustituirse por cero.',
      );
    }
    if (count > 0 && average == null) {
      throw const FormatException(
        'Cuando count es mayor a 0, average es obligatorio.',
      );
    }
    return RatingSummary(
      materialId: QualityJson.requiredUuid(json, 'materialId'),
      count: count,
      average: average,
    );
  }

  Map<String, dynamic> toJson() => {
    'materialId': materialId,
    'count': count,
    'average': average,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RatingSummary &&
          runtimeType == other.runtimeType &&
          materialId == other.materialId &&
          count == other.count &&
          average == other.average;

  @override
  int get hashCode => Object.hash(materialId, count, average);

  @override
  String toString() =>
      'RatingSummary(materialId: $materialId, count: $count, average: $average)';
}

/// DTO para crear o actualizar una calificación propia (`RatingUpsertDto`).
class RatingUpsert {
  final int score;
  final String? comment;

  const RatingUpsert({required this.score, this.comment})
    : assert(score >= 1 && score <= 5, 'Score debe estar entre 1 y 5');

  factory RatingUpsert.fromJson(Map<String, dynamic> json) {
    return RatingUpsert(
      score: QualityJson.requiredInteger(json, 'score', min: 1, max: 5),
      comment: QualityJson.text(json, 'comment'),
    );
  }

  Map<String, dynamic> toJson() => {
    'score': score,
    if (comment != null && comment!.trim().isNotEmpty) 'comment': comment!.trim(),
  };
}
