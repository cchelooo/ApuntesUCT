import 'report_model.dart';

/// Motivos contractuales de reporte de material (`ReportReason` en `quality.openapi.json`).
///
/// Alinea las opciones del formulario con los códigos publicados por Quality Service:
/// - `INAPPROPRIATE_CONTENT`
/// - `COPYRIGHT`
/// - `INCORRECT_INFORMATION`
/// - `BROKEN_RESOURCE`
/// - `OTHER` (exige `details` no vacío después de trim)
enum ReportMotive {
  inappropriateContent(
    'INAPPROPRIATE_CONTENT',
    'Contenido inapropiado u ofensivo',
    ReportReason.inappropriateContent,
  ),
  copyright(
    'COPYRIGHT',
    'Infracción de derechos de autor',
    ReportReason.copyright,
  ),
  incorrectInformation(
    'INCORRECT_INFORMATION',
    'Información errónea o desactualizada',
    ReportReason.incorrectInformation,
  ),
  brokenResource(
    'BROKEN_RESOURCE',
    'Recurso dañado o enlace roto',
    ReportReason.brokenResource,
  ),
  other(
    'OTHER',
    'Otro motivo',
    ReportReason.other,
  );

  final String code;
  final String label;
  final ReportReason reason;

  const ReportMotive(this.code, this.label, this.reason);

  /// Indica si el contrato exige `details` obligatorio para este motivo (`OTHER`).
  bool get requiresDetails => reason == ReportReason.other;

  /// Construye el DTO contractual [ReportCreate] a partir del motivo y detalle ingresado.
  ReportCreate toReportCreate([String? details]) {
    final trimmed = details?.trim();
    return ReportCreate(
      reason: reason,
      details: (trimmed != null && trimmed.isNotEmpty) ? trimmed : null,
    );
  }
}
