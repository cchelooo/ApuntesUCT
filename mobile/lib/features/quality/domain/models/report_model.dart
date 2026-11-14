import 'quality_json.dart';

/// Motivo contractual de reporte (`ReportReason` en OpenAPI / `ReportCreateDto.reason`).
enum ReportReason {
  inappropriateContent('INAPPROPRIATE_CONTENT', 'Contenido inapropiado u ofensivo'),
  copyright('COPYRIGHT', 'Infracción de derechos de autor'),
  incorrectInformation('INCORRECT_INFORMATION', 'Información errónea o desactualizada'),
  brokenResource('BROKEN_RESOURCE', 'Recurso dañado o enlace roto'),
  other('OTHER', 'Otro motivo');

  final String code;
  final String label;

  const ReportReason(this.code, this.label);

  static ReportReason fromJson(Object? value) {
    if (value is! String) {
      throw const FormatException('El motivo de reporte debe ser un texto.');
    }
    return switch (value.trim().toUpperCase()) {
      'INAPPROPRIATE_CONTENT' => inappropriateContent,
      'COPYRIGHT' => copyright,
      'INCORRECT_INFORMATION' => incorrectInformation,
      'BROKEN_RESOURCE' => brokenResource,
      'OTHER' => other,
      _ => throw FormatException('Motivo de reporte no reconocido: $value'),
    };
  }

  String toJson() => code;
}

/// Estado de tratamiento de un reporte (`ReportDto.status`).
enum ReportStatus {
  open('OPEN', 'Abierto'),
  inReview('IN_REVIEW', 'En revisión'),
  resolved('RESOLVED', 'Resuelto'),
  dismissed('DISMISSED', 'Desestimado');

  final String code;
  final String label;

  const ReportStatus(this.code, this.label);

  static ReportStatus fromJson(Object? value) {
    if (value is! String) {
      throw const FormatException('El estado del reporte debe ser un texto.');
    }
    return switch (value.trim().toUpperCase()) {
      'OPEN' => open,
      'IN_REVIEW' => inReview,
      'RESOLVED' => resolved,
      'DISMISSED' => dismissed,
      _ => throw FormatException('Estado de reporte no reconocido: $value'),
    };
  }

  String toJson() => code;
}

/// Representación completa de un reporte (`ReportDto`).
class Report {
  final String id;
  final String materialId;
  final String userId;
  final ReportReason reason;
  final String? details;
  final ReportStatus status;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Report({
    required this.id,
    required this.materialId,
    required this.userId,
    required this.reason,
    this.details,
    required this.status,
    this.resolutionNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: QualityJson.requiredUuid(json, 'id'),
      materialId: QualityJson.requiredUuid(json, 'materialId'),
      userId: QualityJson.requiredUuid(json, 'userId'),
      reason: ReportReason.fromJson(json['reason']),
      details: QualityJson.text(json, 'details'),
      status: ReportStatus.fromJson(json['status']),
      resolutionNote: QualityJson.text(json, 'resolutionNote'),
      createdAt: QualityJson.requiredTimestamp(json, 'createdAt'),
      updatedAt: QualityJson.requiredTimestamp(json, 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'materialId': materialId,
    'userId': userId,
    'reason': reason.toJson(),
    if (details != null) 'details': details,
    'status': status.toJson(),
    if (resolutionNote != null) 'resolutionNote': resolutionNote,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Report &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          materialId == other.materialId &&
          userId == other.userId &&
          reason == other.reason &&
          details == other.details &&
          status == other.status &&
          resolutionNote == other.resolutionNote &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    materialId,
    userId,
    reason,
    details,
    status,
    resolutionNote,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Report(id: $id, materialId: $materialId, status: ${status.code}, reason: ${reason.code})';
}

/// DTO para crear un reporte nuevo (`ReportCreateDto`).
class ReportCreate {
  final ReportReason reason;
  final String? details;

  const ReportCreate({required this.reason, this.details});

  factory ReportCreate.fromJson(Map<String, dynamic> json) {
    return ReportCreate(
      reason: ReportReason.fromJson(json['reason']),
      details: QualityJson.text(json, 'details'),
    );
  }

  Map<String, dynamic> toJson() => {
    'reason': reason.toJson(),
    if (details != null && details!.trim().isNotEmpty) 'details': details!.trim(),
  };
}

/// DTO para actualizar el estado de tratamiento de un reporte (`ReportUpdateDto`).
class ReportUpdate {
  final ReportStatus status;
  final DateTime expectedUpdatedAt;
  final String? resolutionNote;

  const ReportUpdate({
    required this.status,
    required this.expectedUpdatedAt,
    this.resolutionNote,
  }) : assert(
         status == ReportStatus.inReview ||
             status == ReportStatus.resolved ||
             status == ReportStatus.dismissed,
         'ReportUpdate sólo admite estados IN_REVIEW, RESOLVED o DISMISSED',
       );

  factory ReportUpdate.fromJson(Map<String, dynamic> json) {
    return ReportUpdate(
      status: ReportStatus.fromJson(json['status']),
      expectedUpdatedAt: QualityJson.requiredTimestamp(json, 'expectedUpdatedAt'),
      resolutionNote: QualityJson.text(json, 'resolutionNote'),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status.toJson(),
    'expectedUpdatedAt': expectedUpdatedAt.toUtc().toIso8601String(),
    if (resolutionNote != null && resolutionNote!.trim().isNotEmpty)
      'resolutionNote': resolutionNote!.trim(),
  };
}

/// Página de reportes (`ReportPageDto`).
class ReportPage {
  final List<Report> items;
  final int page;
  final int pageSize;
  final int total;

  const ReportPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  int get totalPages => (total / pageSize).ceil();
  bool get hasNextPage => page < totalPages;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  factory ReportPage.fromJson(Map<String, dynamic> json) {
    final page = QualityJson.requiredInteger(json, 'page', min: 1);
    final pageSize = QualityJson.requiredInteger(json, 'pageSize', min: 1, max: 100);
    final total = QualityJson.requiredInteger(json, 'total', min: 0);
    final items = QualityJson.list(
      json,
      'items',
      (item) => Report.fromJson(QualityJson.object(item)),
    );

    return ReportPage(
      items: List.unmodifiable(items),
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((r) => r.toJson()).toList(),
    'page': page,
    'pageSize': pageSize,
    'total': total,
  };
}
