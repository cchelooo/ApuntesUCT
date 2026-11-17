import 'quality_json.dart';

/// Estructura estándar de error devuelta por Quality Service (`ErrorDto`).
class QualityError implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final String? field;
  final String requestId;

  const QualityError({
    required this.statusCode,
    required this.code,
    required this.message,
    this.field,
    required this.requestId,
  });

  factory QualityError.fromJson(Map<String, dynamic> json) {
    return QualityError(
      statusCode: QualityJson.requiredInteger(json, 'statusCode'),
      code: QualityJson.requiredText(json, 'code'),
      message: QualityJson.requiredText(json, 'message'),
      field: QualityJson.text(json, 'field'),
      requestId: QualityJson.requiredUuid(json, 'requestId'),
    );
  }

  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'code': code,
    'message': message,
    if (field != null) 'field': field,
    'requestId': requestId,
  };

  @override
  String toString() =>
      'QualityError(statusCode: $statusCode, code: $code, message: $message, requestId: $requestId)';
}
