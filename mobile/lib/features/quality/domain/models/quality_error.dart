import '../../../../core/errors/api_exception.dart';
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

/// Excepción de API específica para Quality, conservando código y campo de fallo.
class QualityApiException extends ApiException {
  final String? errorCode;
  final String? field;
  final String? requestId;

  QualityApiException({
    required super.message,
    super.statusCode,
    this.errorCode,
    this.field,
    this.requestId,
    super.data,
  });

  factory QualityApiException.fromApiException(ApiException error) {
    if (error.data is Map<String, dynamic>) {
      final json = error.data as Map<String, dynamic>;
      return QualityApiException(
        message: error.message,
        statusCode: error.statusCode,
        errorCode: json['code'] as String?,
        field: json['field'] as String?,
        requestId: json['requestId'] as String?,
        data: error.data,
      );
    }
    return QualityApiException(
      message: error.message,
      statusCode: error.statusCode,
      data: error.data,
    );
  }

  @override
  String toString() =>
      'QualityApiException(statusCode: $statusCode, errorCode: $errorCode, message: $message, field: $field, requestId: $requestId)';
}
