import '../../domain/models/pending_moderation_item.dart';

/// DTO privado de Quality Service para un ítem en la cola de moderación (#409).
///
/// Desacopla el contrato privado de `/quality/moderation/pending` del DTO
/// público de listado de materiales (`GET /materials`).
class QualityModerationItemDto {
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

  const QualityModerationItemDto({
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

  factory QualityModerationItemDto.fromJson(Map<String, dynamic> json) {
    final nestedMaterial = json['material'] is Map
        ? Map<String, dynamic>.from(json['material'] as Map)
        : const <String, dynamic>{};

    String? readString(String key, [String? altKey]) {
      final raw =
          json[key] ??
          (altKey != null ? json[altKey] : null) ??
          nestedMaterial[key] ??
          (altKey != null ? nestedMaterial[altKey] : null);
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
      return null;
    }

    int? readInt(String key, [String? altKey]) {
      final raw =
          json[key] ??
          (altKey != null ? json[altKey] : null) ??
          nestedMaterial[key] ??
          (altKey != null ? nestedMaterial[altKey] : null);
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim());
      return null;
    }

    final materialId =
        readString('materialId') ??
        (nestedMaterial['id'] is String
            ? (nestedMaterial['id'] as String).trim()
            : null) ??
        readString('id');

    if (materialId == null || materialId.isEmpty) {
      throw const FormatException(
        'El ítem de moderación de Quality no incluye materialId.',
      );
    }

    final title = readString('title');
    if (title == null || title.isEmpty) {
      throw const FormatException(
        'El ítem de moderación de Quality no incluye título.',
      );
    }

    final rawReviewId =
        json['reviewId'] ?? (json['materialId'] != null ? json['id'] : null);
    final reviewId = rawReviewId is String && rawReviewId.trim().isNotEmpty
        ? rawReviewId.trim()
        : null;

    final rawTimestamp = readString('submittedAt', 'createdAt');
    final submittedAt = rawTimestamp != null
        ? DateTime.tryParse(rawTimestamp)
        : null;

    return QualityModerationItemDto(
      reviewId: reviewId,
      materialId: materialId,
      materialVersionId: readString('materialVersionId', 'versionId'),
      title: title,
      description: readString('description') ?? '',
      authorName: readString('authorName', 'author') ?? 'Anónimo',
      uploaderId: readString('uploaderId', 'userId'),
      subjectName: readString('subjectName', 'subject') ?? 'General',
      careerName: readString('careerName') ?? 'UCT',
      professor: readString('professor'),
      fileType: readString('fileType', 'mimeType') ?? '',
      materialType: readString('materialType', 'type') ?? '',
      academicYear: readInt('academicYear', 'year'),
      status: readString('status') ?? 'PENDING_REVIEW',
      submittedAt: submittedAt,
    );
  }

  PendingModerationItem toDomain() {
    return PendingModerationItem(
      reviewId: reviewId,
      materialId: materialId,
      materialVersionId: materialVersionId,
      title: title,
      description: description,
      authorName: authorName,
      uploaderId: uploaderId,
      subjectName: subjectName,
      careerName: careerName,
      professor: professor,
      fileType: fileType,
      materialType: materialType,
      academicYear: academicYear,
      status: status,
      submittedAt: submittedAt,
    );
  }
}

/// DTO privado paginado de Quality Service para la cola de revisión (#409).
class QualityModerationPageDto {
  final List<QualityModerationItemDto> items;
  final int page;
  final int pageSize;
  final int total;

  const QualityModerationPageDto({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory QualityModerationPageDto.fromJson(Map<String, dynamic> json) {
    final rawList = json['items'] ?? json['data'];
    if (rawList is! List) {
      throw const FormatException(
        'La respuesta de Quality no contiene la lista de items.',
      );
    }

    int? parsePositiveInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final page = parsePositiveInt(json['page']) ?? 1;
    final pageSize = parsePositiveInt(json['pageSize']) ?? 10;
    final total = parsePositiveInt(json['total']) ?? rawList.length;

    if (page < 1 || pageSize < 1 || total < 0) {
      throw const FormatException(
        'Metadatos de paginación inválidos en cola de Quality.',
      );
    }

    final parsedItems = rawList.map((raw) {
      if (raw is! Map) {
        throw const FormatException('Elemento inválido en cola de Quality.');
      }
      return QualityModerationItemDto.fromJson(Map<String, dynamic>.from(raw));
    }).toList();

    return QualityModerationPageDto(
      items: parsedItems,
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }

  PendingModerationPage toDomain() {
    return PendingModerationPage(
      items: items.map((dto) => dto.toDomain()).toList(),
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }
}
