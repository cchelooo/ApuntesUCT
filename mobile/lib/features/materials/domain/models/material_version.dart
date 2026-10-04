import 'material_json.dart';

class MaterialVersion {
  final String id;
  final String materialId;
  final int versionNumber;
  final String? originalFileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? storageKey;
  final String? checksum;
  final String? createdBy;
  final DateTime? createdAt;

  const MaterialVersion({
    required this.id,
    required this.materialId,
    required this.versionNumber,
    this.originalFileName,
    this.mimeType,
    this.fileSizeBytes,
    this.storageKey,
    this.checksum,
    this.createdBy,
    this.createdAt,
  });

  factory MaterialVersion.fromJson(Map<String, dynamic> json) {
    final number = MaterialJson.integer(json, 'versionNumber', min: 1);
    if (number == null) throw const FormatException('Falta versionNumber.');
    return MaterialVersion(
      id: MaterialJson.requiredText(json, 'id'),
      materialId: MaterialJson.requiredText(json, 'materialId'),
      versionNumber: number,
      originalFileName: MaterialJson.text(json, 'originalFileName'),
      mimeType: MaterialJson.text(json, 'mimeType'),
      fileSizeBytes: MaterialJson.integer(json, 'fileSizeBytes'),
      storageKey: MaterialJson.text(json, 'storageKey'),
      checksum: MaterialJson.text(json, 'checksum'),
      createdBy: MaterialJson.text(json, 'createdBy'),
      createdAt: MaterialJson.timestamp(json, 'createdAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'materialId': materialId,
    'versionNumber': versionNumber,
    if (originalFileName != null) 'originalFileName': originalFileName,
    if (mimeType != null) 'mimeType': mimeType,
    if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
    if (storageKey != null) 'storageKey': storageKey,
    if (checksum != null) 'checksum': checksum,
    if (createdBy != null) 'createdBy': createdBy,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}
