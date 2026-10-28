import '../domain/models/material_detail.dart';
import '../domain/models/material_json.dart';

/// Traduce MaterialDetailDto de INT2 al formato del dominio Mobile.
///
/// Conserva el historial completo (`versions[]` descendente) y resuelve
/// `currentVersionId` desde `currentVersion` (#293). Si el payload solo trae
/// `currentVersion` (fixtures previos), se usa como única entrada.
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

  final materialId = MaterialJson.requiredText(payload, 'id');
  final currentMapped = _mapVersion(MaterialJson.object(current), materialId);

  // Historial completo del DTO; las entradas corruptas se omiten sin
  // invalidar el detalle (la actual siempre se conserva).
  final rawVersions = payload['versions'];
  final mapped = <Map<String, Object?>>[];
  if (rawVersions is List) {
    for (final entry in rawVersions) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        final mappedEntry = _mapVersion(
          Map<String, dynamic>.from(entry),
          materialId,
        );
        if (mapped.any((v) => v['id'] == mappedEntry['id'])) continue;
        mapped.add(mappedEntry);
      } catch (_) {
        // Entrada corrupta: se omite, la actual la suple.
      }
    }
  }
  if (!mapped.any((v) => v['id'] == currentMapped['id'])) {
    mapped.insert(0, currentMapped);
  }

  return MaterialDetail.fromJson({
    ...payload,
    'versions': mapped,
    'currentVersionId': currentMapped['id'],
    'fileSizeBytes': currentMapped['fileSizeBytes'],
  });
}

/// Mapea una entrada de versión del DTO al formato interno.
/// Lanza [FormatException] si el formato no coincide con el contrato.
Map<String, Object?> _mapVersion(
  Map<String, dynamic> version,
  String materialId,
) {
  final size = MaterialJson.requiredText(version, 'fileSize');
  final bytes = int.tryParse(size);
  if (!RegExp(r'^(0|[1-9]\d*)$').hasMatch(size) || bytes == null) {
    throw const FormatException(
      'fileSize debe ser una cadena decimal de bytes.',
    );
  }
  return {
    'id': MaterialJson.requiredText(version, 'id'),
    'materialId': materialId,
    'versionNumber': MaterialJson.integer(version, 'versionNumber', min: 1),
    'originalFileName': MaterialJson.requiredText(version, 'originalFilename'),
    'mimeType': MaterialJson.requiredText(version, 'mimeType'),
    'fileSizeBytes': bytes,
    'createdAt': version['createdAt'],
  };
}
