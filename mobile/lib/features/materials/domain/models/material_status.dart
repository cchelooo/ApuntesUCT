/// Estado del dominio Mobile. GET /materials publica PUBLISHED en OpenAPI;
/// APPROVED se conserva por compatibilidad con los fixtures visuales.
enum MaterialStatus {
  pendingReview('PENDING_REVIEW'),
  published('PUBLISHED'),
  approved('APPROVED'),
  rejected('REJECTED'),
  withdrawn('WITHDRAWN'),
  unknown('UNKNOWN');

  const MaterialStatus(this.code);

  final String code;

  String get label => switch (this) {
    pendingReview => 'En revisión',
    published => 'Publicado',
    approved => 'Aprobado',
    rejected => 'Rechazado',
    withdrawn => 'Retirado',
    unknown => 'Sin estado',
  };

  /// Acepta las etiquetas de los fixtures visuales existentes. Un valor
  /// ausente o desconocido nunca se interpreta como material aprobado.
  static MaterialStatus fromJson(Object? value) {
    if (value == null) return unknown;
    if (value is! String) {
      throw const FormatException('El estado del material debe ser un texto.');
    }

    return switch (value.trim().toUpperCase()) {
      'PENDING_REVIEW' || 'PENDIENTE' => pendingReview,
      'PUBLISHED' => published,
      'APPROVED' || 'APROBADO' => approved,
      'REJECTED' || 'RECHAZADO' => rejected,
      'WITHDRAWN' || 'RETIRADO' => withdrawn,
      _ => unknown,
    };
  }

  String toJson() => code;
}
