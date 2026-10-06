import 'material_json.dart';
import 'material_summary.dart';
import 'material_version.dart';

class MaterialDetail {
  final MaterialSummary summary;
  final String downloadUrl;
  final int fileSizeBytes;
  final List<String> tags;
  final int viewCount;
  final List<MaterialVersion> versions;
  final String? currentVersionId;

  MaterialDetail({
    required this.summary,
    this.downloadUrl = '',
    this.fileSizeBytes = 0,
    List<String> tags = const [],
    this.viewCount = 0,
    List<MaterialVersion> versions = const [],
    this.currentVersionId,
  }) : tags = List.unmodifiable(tags),
       versions = List.unmodifiable(versions);

  MaterialVersion? get currentVersion {
    for (final version in versions) {
      if (version.id == currentVersionId) return version;
    }
    return null;
  }

  factory MaterialDetail.fromJson(Map<String, dynamic> json) {
    final summary = MaterialSummary.fromJson(json);
    final versions = MaterialJson.list(
      json,
      'versions',
      (value) => MaterialVersion.fromJson(MaterialJson.object(value)),
    );
    if (versions.any((version) => version.materialId != summary.id)) {
      throw const FormatException('Una versión pertenece a otro material.');
    }
    return MaterialDetail(
      summary: summary,
      downloadUrl: MaterialJson.text(json, 'downloadUrl') ?? '',
      fileSizeBytes: MaterialJson.integer(json, 'fileSizeBytes') ?? 0,
      tags: MaterialJson.list(json, 'tags', (value) {
        if (value is! String) {
          throw const FormatException('Las etiquetas deben ser textos.');
        }
        return value;
      }),
      viewCount: MaterialJson.integer(json, 'viewCount') ?? 0,
      versions: versions,
      currentVersionId: MaterialJson.text(json, 'currentVersionId'),
    );
  }

  Map<String, dynamic> toJson() => {
    ...summary.toJson(),
    'downloadUrl': downloadUrl,
    'fileSizeBytes': fileSizeBytes,
    'tags': tags,
    'viewCount': viewCount,
    'versions': versions.map((version) => version.toJson()).toList(),
    if (currentVersionId != null) 'currentVersionId': currentVersionId,
  };
}
