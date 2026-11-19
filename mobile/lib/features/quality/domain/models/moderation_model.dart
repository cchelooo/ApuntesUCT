import 'quality_json.dart';

/// Estados de publicación reconocidos por el servicio de Quality (`MaterialStatus` en OpenAPI).
enum QualityMaterialStatus {
  pendingReview('PENDING_REVIEW', 'En revisión'),
  published('PUBLISHED', 'Publicado'),
  rejected('REJECTED', 'Rechazado'),
  retired('RETIRED', 'Retirado');

  final String code;
  final String label;

  const QualityMaterialStatus(this.code, this.label);

  static QualityMaterialStatus fromJson(Object? value) {
    if (value is! String) {
      throw const FormatException('El estado del material debe ser un texto.');
    }
    return switch (value.trim().toUpperCase()) {
      'PENDING_REVIEW' || 'PENDIENTE' => pendingReview,
      'PUBLISHED' => published,
      'REJECTED' || 'RECHAZADO' => rejected,
      'RETIRED' || 'RETIRADO' || 'WITHDRAWN' => retired,
      _ => throw FormatException('Estado de material no reconocido: $value'),
    };
  }

  String toJson() => code;
}

/// Acciones de moderación autorizadas (`ModerationAction`).
enum ModerationAction {
  approve('APPROVE', 'Aprobar'),
  reject('REJECT', 'Rechazar'),
  verify('VERIFY', 'Verificar'),
  revokeVerification('REVOKE_VERIFICATION', 'Revocar verificación'),
  retire('RETIRE', 'Retirar'),
  reopen('REOPEN', 'Reabrir');

  final String code;
  final String label;

  const ModerationAction(this.code, this.label);

  static ModerationAction fromJson(Object? value) {
    if (value is! String) {
      throw const FormatException('La acción de moderación debe ser un texto.');
    }
    return switch (value.trim().toUpperCase()) {
      'APPROVE' => approve,
      'REJECT' => reject,
      'VERIFY' => verify,
      'REVOKE_VERIFICATION' => revokeVerification,
      'RETIRE' => retire,
      'REOPEN' => reopen,
      _ => throw FormatException('Acción de moderación no reconocida: $value'),
    };
  }

  String toJson() => code;
}

/// Estado del procesamiento asíncrono o idempotente de una operación de moderación.
enum ModerationOperationState {
  pendingApplication('PENDING_APPLICATION'),
  applied('APPLIED'),
  failed('FAILED');

  final String code;

  const ModerationOperationState(this.code);

  static ModerationOperationState fromJson(Object? value) {
    if (value is! String) {
      throw const FormatException('El estado de la operación debe ser un texto.');
    }
    return switch (value.trim().toUpperCase()) {
      'PENDING_APPLICATION' => pendingApplication,
      'APPLIED' => applied,
      'FAILED' => failed,
      _ => throw FormatException('Estado de operación no reconocido: $value'),
    };
  }

  String toJson() => code;
}

/// Snapshot del resultado aplicado sobre un material tras moderación (`AppliedMaterialDtoNullable`).
class AppliedMaterial {
  final String materialId;
  final QualityMaterialStatus status;
  final bool verified;
  final int revision;

  const AppliedMaterial({
    required this.materialId,
    required this.status,
    required this.verified,
    required this.revision,
  });

  factory AppliedMaterial.fromJson(Map<String, dynamic> json) {
    return AppliedMaterial(
      materialId: QualityJson.requiredUuid(json, 'materialId'),
      status: QualityMaterialStatus.fromJson(json['status']),
      verified: QualityJson.requiredBoolean(json, 'verified'),
      revision: QualityJson.requiredInteger(json, 'revision', min: 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'materialId': materialId,
    'status': status.toJson(),
    'verified': verified,
    'revision': revision,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppliedMaterial &&
          runtimeType == other.runtimeType &&
          materialId == other.materialId &&
          status == other.status &&
          verified == other.verified &&
          revision == other.revision;

  @override
  int get hashCode => Object.hash(materialId, status, verified, revision);
}

/// Detalle del fallo en la aplicación de una decisión de moderación (`OperationFailureDtoNullable`).
class OperationFailure {
  final int statusCode;
  final String code;
  final String message;

  const OperationFailure({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  factory OperationFailure.fromJson(Map<String, dynamic> json) {
    return OperationFailure(
      statusCode: QualityJson.requiredInteger(json, 'statusCode'),
      code: QualityJson.requiredText(json, 'code'),
      message: QualityJson.requiredText(json, 'message'),
    );
  }

  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'code': code,
    'message': message,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperationFailure &&
          runtimeType == other.runtimeType &&
          statusCode == other.statusCode &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(statusCode, code, message);
}

/// Operación de moderación registrada de forma idempotente (`ModerationOperationDto`).
class ModerationOperation {
  final String id;
  final String materialId;
  final String actorId;
  final ModerationAction action;
  final String? reason;
  final int expectedRevision;
  final ModerationOperationState state;
  final AppliedMaterial? result;
  final OperationFailure? failure;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ModerationOperation({
    required this.id,
    required this.materialId,
    required this.actorId,
    required this.action,
    this.reason,
    required this.expectedRevision,
    required this.state,
    this.result,
    this.failure,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ModerationOperation.fromJson(Map<String, dynamic> json) {
    return ModerationOperation(
      id: QualityJson.requiredUuid(json, 'id'),
      materialId: QualityJson.requiredUuid(json, 'materialId'),
      actorId: QualityJson.requiredUuid(json, 'actorId'),
      action: ModerationAction.fromJson(json['action']),
      reason: QualityJson.text(json, 'reason'),
      expectedRevision: QualityJson.requiredInteger(json, 'expectedRevision', min: 0),
      state: ModerationOperationState.fromJson(json['state']),
      result: json['result'] != null
          ? AppliedMaterial.fromJson(QualityJson.object(json['result']))
          : null,
      failure: json['failure'] != null
          ? OperationFailure.fromJson(QualityJson.object(json['failure']))
          : null,
      createdAt: QualityJson.requiredTimestamp(json, 'createdAt'),
      updatedAt: QualityJson.requiredTimestamp(json, 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'materialId': materialId,
    'actorId': actorId,
    'action': action.toJson(),
    'reason': reason,
    'expectedRevision': expectedRevision,
    'state': state.toJson(),
    'result': result?.toJson(),
    'failure': failure?.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModerationOperation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          materialId == other.materialId &&
          state == other.state;

  @override
  int get hashCode => Object.hash(id, materialId, state);
}

/// Solicitud de decisión de moderación (`ModerationDecisionRequestDto`).
class ModerationDecisionRequest {
  final ModerationAction action;
  final int expectedRevision;
  final String? reason;

  const ModerationDecisionRequest({
    required this.action,
    required this.expectedRevision,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
    'action': action.toJson(),
    'expectedRevision': expectedRevision,
    if (reason != null && reason!.trim().isNotEmpty) 'reason': reason!.trim(),
  };
}

/// Metadatos de versión de material en snapshot de moderación (`MaterialVersionDto`).
class ModerationMaterialVersion {
  final String id;
  final int versionNumber;
  final String originalFilename;
  final String mimeType;
  final String fileSize;
  final DateTime createdAt;

  const ModerationMaterialVersion({
    required this.id,
    required this.versionNumber,
    required this.originalFilename,
    required this.mimeType,
    required this.fileSize,
    required this.createdAt,
  });

  factory ModerationMaterialVersion.fromJson(Map<String, dynamic> json) {
    return ModerationMaterialVersion(
      id: QualityJson.requiredUuid(json, 'id'),
      versionNumber: QualityJson.requiredInteger(json, 'versionNumber', min: 1),
      originalFilename: QualityJson.requiredText(json, 'originalFilename'),
      mimeType: QualityJson.requiredText(json, 'mimeType'),
      fileSize: QualityJson.requiredText(json, 'fileSize'),
      createdAt: QualityJson.requiredTimestamp(json, 'createdAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'versionNumber': versionNumber,
    'originalFilename': originalFilename,
    'mimeType': mimeType,
    'fileSize': fileSize,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// Snapshot completo de un material en la cola o gestión de moderación (`ModerationMaterialDto`).
class ModerationMaterial {
  final String id;
  final String uploaderId;
  final String title;
  final String? description;
  final String materialType;
  final String? externalLink;
  final QualityMaterialStatus status;
  final bool verified;
  final int revision;
  final String? currentVersionId;
  final List<ModerationMaterialVersion> versions;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ModerationMaterial({
    required this.id,
    required this.uploaderId,
    required this.title,
    this.description,
    required this.materialType,
    this.externalLink,
    required this.status,
    required this.verified,
    required this.revision,
    this.currentVersionId,
    required this.versions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ModerationMaterial.fromJson(Map<String, dynamic> json) {
    final versions = QualityJson.list(
      json,
      'versions',
      (v) => ModerationMaterialVersion.fromJson(QualityJson.object(v)),
    );

    return ModerationMaterial(
      id: QualityJson.requiredUuid(json, 'id'),
      uploaderId: QualityJson.requiredUuid(json, 'uploaderId'),
      title: QualityJson.requiredText(json, 'title'),
      description: QualityJson.text(json, 'description'),
      materialType: QualityJson.requiredText(json, 'materialType'),
      externalLink: QualityJson.text(json, 'externalLink'),
      status: QualityMaterialStatus.fromJson(json['status']),
      verified: QualityJson.requiredBoolean(json, 'verified'),
      revision: QualityJson.requiredInteger(json, 'revision', min: 0),
      currentVersionId: QualityJson.uuid(json, 'currentVersionId'),
      versions: List.unmodifiable(versions),
      createdAt: QualityJson.requiredTimestamp(json, 'createdAt'),
      updatedAt: QualityJson.requiredTimestamp(json, 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uploaderId': uploaderId,
    'title': title,
    'description': description,
    'materialType': materialType,
    'externalLink': externalLink,
    'status': status.toJson(),
    'verified': verified,
    'revision': revision,
    'currentVersionId': currentVersionId,
    'versions': versions.map((v) => v.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModerationMaterial &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          revision == other.revision;

  @override
  int get hashCode => Object.hash(id, revision);
}

/// Página de materiales para moderación (`ModerationMaterialPageDto`).
class ModerationMaterialPage {
  final List<ModerationMaterial> items;
  final int page;
  final int pageSize;
  final int total;

  const ModerationMaterialPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  int get totalPages => (total / pageSize).ceil();
  bool get hasNextPage => page < totalPages;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  factory ModerationMaterialPage.fromJson(Map<String, dynamic> json) {
    final page = QualityJson.requiredInteger(json, 'page', min: 1);
    final pageSize = QualityJson.requiredInteger(json, 'pageSize', min: 1, max: 100);
    final total = QualityJson.requiredInteger(json, 'total', min: 0);
    final items = QualityJson.list(
      json,
      'items',
      (item) => ModerationMaterial.fromJson(QualityJson.object(item)),
    );

    return ModerationMaterialPage(
      items: List.unmodifiable(items),
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((m) => m.toJson()).toList(),
    'page': page,
    'pageSize': pageSize,
    'total': total,
  };
}
