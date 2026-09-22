/// Modelo de presentación para tarjetas de material en la pantalla Home.
///
/// Intencionalmente separado de `MaterialModel` (que mapea la entidad del
/// Material Service). Los campos [rating] y [downloads] provienen de Quality
/// Service y solo son necesarios en ciertas secciones de la UI, por eso son
/// opcionales. Las tarjetas de "Material recomendado" los omiten (null);
/// las de "Mejores calificados" los incluyen.
///
/// Se usa exclusivamente como modelo de vista — nunca se envía a la API.
class MaterialCardData {
  final String id;
  final String title;
  final String subtitle;
  final double? rating;
  final int? downloads;

  const MaterialCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    this.rating,
    this.downloads,
  });

  // ---------------------------------------------------------------------------
  // Mock factories
  // ---------------------------------------------------------------------------

  /// Lista mock para la sección "Material recomendado" (sin rating/downloads).
  static List<MaterialCardData> mockRecomendado() {
    return const [
      MaterialCardData(
        id: 'mat-rec-01',
        title: 'Guía 3 Cálculo integral',
        subtitle: 'Prof. Constanza',
      ),
      MaterialCardData(
        id: 'mat-rec-02',
        title: 'Resumen Grafos bipartitos',
        subtitle: 'Teoría de Grafos',
      ),
      MaterialCardData(
        id: 'mat-rec-03',
        title: 'Modelo ER normalización',
        subtitle: 'Bases de Datos',
      ),
    ];
  }

  /// Lista mock para la sección "Mejores calificados del día" (con rating y downloads).
  static List<MaterialCardData> mockMejoresCalificados() {
    return const [
      MaterialCardData(
        id: 'mat-top-01',
        title: 'Formulario derivadas',
        subtitle: 'Cálculo Intermedio',
        rating: 4.9,
        downloads: 89,
      ),
      MaterialCardData(
        id: 'mat-top-02',
        title: 'Ayudantía SQL joins',
        subtitle: 'Bases de Datos',
        rating: 4.8,
        downloads: 52,
      ),
      MaterialCardData(
        id: 'mat-top-03',
        title: 'Control 1 resuelto',
        subtitle: 'Teoría de Grafos',
        rating: 4.7,
        downloads: 41,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // copyWith / equality
  // ---------------------------------------------------------------------------

  MaterialCardData copyWith({
    String? id,
    String? title,
    String? subtitle,
    double? rating,
    int? downloads,
  }) {
    return MaterialCardData(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      rating: rating ?? this.rating,
      downloads: downloads ?? this.downloads,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialCardData &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          subtitle == other.subtitle &&
          rating == other.rating &&
          downloads == other.downloads;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      subtitle.hashCode ^
      rating.hashCode ^
      downloads.hashCode;

  @override
  String toString() =>
      'MaterialCardData(id: $id, title: $title, subtitle: $subtitle, '
      'rating: $rating, downloads: $downloads)';
}
