/// Estado del dominio Mobile. Los valores del transporte deben contrastarse
/// con OpenAPI cuando INT2 publique el contrato de Material Service.
enum MaterialStatus {
  pendingReview('PENDING_REVIEW'),
  approved('APPROVED'),
  rejected('REJECTED'),
  withdrawn('WITHDRAWN'),
  unknown('UNKNOWN');

  const MaterialStatus(this.code);

  final String code;

  /// Acepta las etiquetas de los fixtures visuales existentes. Un valor
  /// ausente o desconocido nunca se interpreta como material aprobado.
  static MaterialStatus fromJson(Object? value) {
    if (value == null) return unknown;
    if (value is! String) {
      throw const FormatException('El estado del material debe ser un texto.');
    }

    return switch (value.trim().toUpperCase()) {
      'PENDING_REVIEW' || 'PENDIENTE' => pendingReview,
      'APPROVED' || 'APROBADO' => approved,
      'REJECTED' || 'RECHAZADO' => rejected,
      'WITHDRAWN' || 'RETIRADO' => withdrawn,
      _ => unknown,
    };
  }

  String toJson() => code;
}
