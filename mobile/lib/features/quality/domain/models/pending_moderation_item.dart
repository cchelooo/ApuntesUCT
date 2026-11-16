import '../../../materials/domain/models/material_summary.dart';

/// Entidad de dominio para un material en la cola privada de moderación de Quality.
class PendingModerationItem {
  final String? reviewId;
  final String materialId;
  final String? materialVersionId;
  final String title;
  final String description;
  final String authorName;
  final String? uploaderId;
  final String subjectName;
  final String careerName;
  final String? professor;
  final String fileType;
  final String materialType;
  final int? academicYear;
  final String status;
  final DateTime? submittedAt;

  const PendingModerationItem({
    this.reviewId,
    required this.materialId,
    this.materialVersionId,
    required this.title,
    this.description = '',
    this.authorName = 'Anónimo',
    this.uploaderId,
    this.subjectName = 'General',
    this.careerName = 'UCT',
    this.professor,
    this.fileType = '',
    this.materialType = '',
    this.academicYear,
    this.status = 'PENDING_REVIEW',
    this.submittedAt,
  });

  /// Adapta el ítem privado de moderación para renderizar su tarjeta resumen.
  MaterialSummary toMaterialSummary() {
    return MaterialSummary(
      id: materialId,
      title: title,
      description: description,
      authorName: authorName,
      uploaderId: uploaderId,
      subjectName: subjectName,
      careerName: careerName,
      professor: professor,
      fileType: fileType,
      academicYear: academicYear,
      materialType: materialType,
      status: status,
      createdAt: submittedAt,
    );
  }
}

/// Página de resultados de la cola privada de moderación.
class PendingModerationPage {
  final List<PendingModerationItem> items;
  final int page;
  final int pageSize;
  final int total;

  PendingModerationPage({
    required List<PendingModerationItem> items,
    required this.page,
    required this.pageSize,
    required this.total,
  }) : items = List.unmodifiable(items) {
    if (page < 1 || pageSize < 1 || total < 0) {
      throw ArgumentError('Metadatos de paginación inválidos.');
    }
  }

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();
  bool get hasNextPage => page < totalPages;
}
