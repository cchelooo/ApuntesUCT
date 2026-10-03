import 'material_summary.dart';

class MaterialDetail {
  final MaterialSummary summary;
  final String downloadUrl;
  final int fileSizeBytes;
  final List<String> tags;
  final int viewCount;

  const MaterialDetail({
    required this.summary,
    required this.downloadUrl,
    required this.fileSizeBytes,
    this.tags = const [],
    this.viewCount = 0,
  });

  factory MaterialDetail.fromJson(Map<String, dynamic> json) {
    return MaterialDetail(
      summary: MaterialSummary.fromJson(json),
      downloadUrl: json['downloadUrl'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    final map = summary.toJson();
    map.addAll({
      'downloadUrl': downloadUrl,
      'fileSizeBytes': fileSizeBytes,
      'tags': tags,
      'viewCount': viewCount,
    });
    return map;
  }
}
