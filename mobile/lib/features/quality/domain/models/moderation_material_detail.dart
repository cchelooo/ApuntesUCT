import '../../../materials/domain/models/material_version.dart';

/// Detalle privado de un material en cola de moderación (#410).
class ModerationMaterialDetail {
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

  ModerationMaterialDetail({
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
    List<String> tags = const [],
    this.currentVersionId,
    List<MaterialVersion> versions = const [],
  }) : tags = List.unmodifiable(tags),
       versions = List.unmodifiable(versions);

  bool get isExternalLink => materialType.trim().toUpperCase() == 'LINK';

  /// Valida que el enlace externo use únicamente esquema `http` o `https`.
  Uri? get validatedExternalUri {
    final raw = externalLink?.trim();
    if (raw == null || raw.isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed == null || !parsed.hasAuthority) return null;
    final scheme = parsed.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    return parsed;
  }

  /// Indica si existe un enlace configurado con esquema inseguro o malformado.
  bool get hasUnsafeExternalLink =>
      externalLink != null &&
      externalLink!.trim().isNotEmpty &&
      validatedExternalUri == null;

  /// Versiones ordenadas de la más reciente a la más antigua.
  List<MaterialVersion> get orderedVersions {
    final copy = [...versions];
    copy.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return copy;
  }

  /// Versión activa del material pendiente (por ID o mayor número de versión).
  MaterialVersion? get currentVersion {
    if (currentVersionId != null) {
      for (final version in versions) {
        if (version.id == currentVersionId) return version;
      }
    }
    final sorted = orderedVersions;
    return sorted.isNotEmpty ? sorted.first : null;
  }
}
