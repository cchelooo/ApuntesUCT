import '../domain/models/material_detail.dart';
import '../domain/models/material_json.dart';

/// Traduce MaterialDetailDto de INT2 al formato del dominio Mobile.
MaterialDetail materialDetailFromResponse(Map<String, dynamic> payload) {
  // Compatibilidad con fixtures anteriores de #290; no cambia su serialización.
  if (!payload.containsKey('currentVersion')) {
    return MaterialDetail.fromJson(payload);
  }

  final current = payload['currentVersion'];
  if (current == null) {
    return MaterialDetail.fromJson({
      ...payload,
      'versions': <Object>[],
      'currentVersionId': null,
      'fileSizeBytes': 0,
    });
  }

  final version = MaterialJson.object(current);
  final size = MaterialJson.requiredText(version, 'fileSize');
  final bytes = int.tryParse(size);
  if (!RegExp(r'^(0|[1-9]\d*)$').hasMatch(size) || bytes == null) {
    throw const FormatException(
      'fileSize debe ser una cadena decimal de bytes.',
    );
  }
  final mappedVersion = {
    'id': MaterialJson.requiredText(version, 'id'),
    'materialId': MaterialJson.requiredText(payload, 'id'),
    'versionNumber': MaterialJson.integer(version, 'versionNumber', min: 1),
    'originalFileName': MaterialJson.requiredText(version, 'originalFilename'),
    'mimeType': MaterialJson.requiredText(version, 'mimeType'),
    'fileSizeBytes': bytes,
    'createdAt': version['createdAt'],
  };
  return MaterialDetail.fromJson({
    ...payload,
    'versions': [mappedVersion],
    'currentVersionId': mappedVersion['id'],
    'fileSizeBytes': bytes,
  });
}
