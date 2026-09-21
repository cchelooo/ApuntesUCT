class CatalogItem {
  final String id;
  final String title;
  final String author;
  final String subject;
  final String? description;

  const CatalogItem({
    required this.id,
    required this.title,
    required this.author,
    required this.subject,
    this.description,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: json['id']?.toString() ?? '',
      title:
          json['title'] as String? ?? json['name'] as String? ?? 'Sin título',
      author:
          json['author'] as String? ??
          json['professor'] as String? ??
          json['careerName'] as String? ??
          'Universidad Católica de Temuco',
      subject:
          json['subject'] as String? ??
          json['subjectName'] as String? ??
          json['name'] as String? ??
          'General',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'subject': subject,
      if (description != null) 'description': description,
    };
  }
}
