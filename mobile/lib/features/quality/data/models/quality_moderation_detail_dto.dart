import '../../../materials/domain/models/material_version.dart';
import '../../domain/models/moderation_material_detail.dart';

/// DTO privado de Quality Service para el detalle de moderación (#410).
class QualityModerationDetailDto {
  final String? reviewId;
  final String materialId;
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
  final int fileSizeBytes;
  final String? mimeType;
  final String? externalLink;
  final List<String> tags;
  final String? currentVersionId;
  final List<MaterialVersion> versions;

  const QualityModerationDetailDto({
    this.reviewId,
    required this.materialId,
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
    this.fileSizeBytes = 0,
    this.mimeType,
    this.externalLink,
    this.tags = const [],
    this.currentVersionId,
    this.versions = const [],
  });

  factory QualityModerationDetailDto.fromJson(Map<String, dynamic> rawJson) {
    final json = rawJson['data'] is Map<String, dynamic>
        ? rawJson['data'] as Map<String, dynamic>
        : rawJson;

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
        'El detalle de moderación de Quality no incluye materialId.',
      );
    }

    final title = readString('title');
    if (title == null || title.isEmpty) {
      throw const FormatException(
        'El detalle de moderación de Quality no incluye título.',
      );
    }

    final rawReviewId =
        json['reviewId'] ?? (json['materialId'] != null ? json['id'] : null);
    final reviewId = rawReviewId is String && rawReviewId.trim().isNotEmpty
        ? rawReviewId.trim()
        : null;

    final rawTags = json['tags'] ?? nestedMaterial['tags'];
    final tags = <String>[];
    if (rawTags is List) {
      for (final entry in rawTags) {
        if (entry is String && entry.trim().isNotEmpty) {
          tags.add(entry.trim());
        }
      }
    }

    final rawVersions = json['versions'] ?? nestedMaterial['versions'];
    final parsedVersions = <MaterialVersion>[];
    if (rawVersions is List) {
      for (final rawVersion in rawVersions) {
        if (rawVersion is! Map) {
          throw const FormatException(
            'Elemento de versión inválido en detalle de Quality.',
          );
        }
        final vMap = Map<String, dynamic>.from(rawVersion);
        final vId = (vMap['id'] ?? vMap['versionId'])?.toString().trim();
        if (vId == null || vId.isEmpty) {
          throw const FormatException('Versión sin identificador en Quality.');
        }
        final rawNum = vMap['versionNumber'];
        final vNum = rawNum is int
            ? rawNum
            : (rawNum is num
                  ? rawNum.toInt()
                  : int.tryParse(rawNum?.toString() ?? '') ?? 1);
        final rawSize = vMap['fileSizeBytes'] ?? vMap['fileSize'];
        final vSize = rawSize is int
            ? rawSize
            : (rawSize is num
                  ? rawSize.toInt()
                  : int.tryParse(rawSize?.toString() ?? ''));
        final rawCreated = vMap['createdAt'] ?? vMap['submittedAt'];
        parsedVersions.add(
          MaterialVersion(
            id: vId,
            materialId: materialId,
            versionNumber: vNum < 1 ? 1 : vNum,
            originalFileName:
                (vMap['originalFileName'] ?? vMap['originalFilename'])
                    ?.toString(),
            mimeType: vMap['mimeType']?.toString(),
            fileSizeBytes: vSize,
            storageKey: null,
            checksum: vMap['checksum']?.toString(),
            createdBy: vMap['createdBy']?.toString(),
            createdAt: rawCreated is String
                ? DateTime.tryParse(rawCreated)
                : null,
          ),
        );
      }
    }

    final rawCurrentVersion =
        json['currentVersion'] ?? nestedMaterial['currentVersion'];
    String? currentVersionId = readString('currentVersionId', 'versionId');
    if (rawCurrentVersion is Map) {
      final cvMap = Map<String, dynamic>.from(rawCurrentVersion);
      final cvId = (cvMap['id'] ?? cvMap['versionId'])?.toString().trim();
      if (cvId != null && cvId.isNotEmpty) {
        currentVersionId ??= cvId;
        if (!parsedVersions.any((v) => v.id == cvId)) {
          final rawNum = cvMap['versionNumber'];
          final cvNum = rawNum is int
              ? rawNum
              : int.tryParse(rawNum?.toString() ?? '') ?? 1;
          final rawSize = cvMap['fileSizeBytes'] ?? cvMap['fileSize'];
          final cvSize = rawSize is int
              ? rawSize
              : int.tryParse(rawSize?.toString() ?? '');
          parsedVersions.add(
            MaterialVersion(
              id: cvId,
              materialId: materialId,
              versionNumber: cvNum < 1 ? 1 : cvNum,
              originalFileName:
                  (cvMap['originalFileName'] ?? cvMap['originalFilename'])
                      ?.toString(),
              mimeType: cvMap['mimeType']?.toString(),
              fileSizeBytes: cvSize,
              createdAt: cvMap['createdAt'] is String
                  ? DateTime.tryParse(cvMap['createdAt'] as String)
                  : null,
            ),
          );
        }
      }
    }

    final rawTimestamp = readString('submittedAt', 'createdAt');
    final submittedAt = rawTimestamp != null
        ? DateTime.tryParse(rawTimestamp)
        : null;

    return QualityModerationDetailDto(
      reviewId: reviewId,
      materialId: materialId,
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
      fileSizeBytes: readInt('fileSizeBytes', 'fileSize') ?? 0,
      mimeType: readString('mimeType'),
      externalLink: readString('externalLink'),
      tags: tags,
      currentVersionId: currentVersionId,
      versions: parsedVersions,
    );
  }

  ModerationMaterialDetail toDomain() {
    return ModerationMaterialDetail(
      reviewId: reviewId,
      materialId: materialId,
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
      fileSizeBytes: fileSizeBytes,
      mimeType: mimeType,
      externalLink: externalLink,
      tags: tags,
      currentVersionId: currentVersionId,
      versions: versions,
    );
  }
}
