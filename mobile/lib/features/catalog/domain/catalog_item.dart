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
          json['title'] as String? ?? json['name'] as String? ?? 'Sem título',
      author:
          json['author'] as String? ??
          json['professor'] as String? ??
          json['user']?['name'] as String? ??
          'Autor desconhecido',
      subject:
          json['subject'] as String? ??
          json['subject']?['name'] as String? ??
          json['career']?['name'] as String? ??
          'Geral',
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
