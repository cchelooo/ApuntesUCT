class MaterialSummary {
  final String id;
  final String title;
  final String description;
  final String authorName;
  final String subjectName;
  final String careerName;
  final String fileType;
  final int downloadCount;
  final double rating;
  final DateTime createdAt;

  const MaterialSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.authorName,
    required this.subjectName,
    required this.careerName,
    required this.fileType,
    this.downloadCount = 0,
    this.rating = 0.0,
    required this.createdAt,
  });

  factory MaterialSummary.fromJson(Map<String, dynamic> json) {
    return MaterialSummary(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Sin título',
      description: json['description'] as String? ?? '',
      authorName:
          json['authorName'] as String? ??
          json['author'] as String? ??
          'Anónimo',
      subjectName:
          json['subjectName'] as String? ??
          json['subject'] as String? ??
          'General',
      careerName: json['careerName'] as String? ?? 'UCT',
      fileType: json['fileType'] as String? ?? 'pdf',
      downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'authorName': authorName,
      'subjectName': subjectName,
      'careerName': careerName,
      'fileType': fileType,
      'downloadCount': downloadCount,
      'rating': rating,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
