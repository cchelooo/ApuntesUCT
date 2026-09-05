/// Modelo inmutable que representa un profesor en el catálogo académico.
/// Mapea la entidad PROFESSOR proveniente de Catalog Service.
class ProfessorModel {
  final String id;
  final String name;
  final String email;
  final bool active;

  const ProfessorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.active,
  });

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  factory ProfessorModel.fromJson(Map<String, dynamic> json) {
    return ProfessorModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      active: json['active'] as bool? ?? true,
    );
  }

  /// Serializa el modelo a un mapa JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'active': active,
    };
  }

  /// Factory para generar una instancia MOCK de ejemplo.
  factory ProfessorModel.mock({
    String id = 'prof-mellado-uuid',
    String name = 'Nelson Mellado',
    String email = 'nmellado@uct.cl',
    bool active = true,
  }) {
    return ProfessorModel(
      id: id,
      name: name,
      email: email,
      active: active,
    );
  }

  /// Lista de profesores MOCK para poblar catálogos y filtros de búsqueda.
  static List<ProfessorModel> mockList() {
    return [
      ProfessorModel.mock(
        id: 'prof-mellado-uuid',
        name: 'Nelson Mellado',
        email: 'nmellado@uct.cl',
        active: true,
      ),
      ProfessorModel.mock(
        id: 'prof-rodriguez-uuid',
        name: 'Alejandro Rodríguez',
        email: 'arodriguez@uct.cl',
        active: true,
      ),
      ProfessorModel.mock(
        id: 'prof-navarro-uuid',
        name: 'Carlos Navarro',
        email: 'cnavarro@uct.cl',
        active: true,
      ),
    ];
  }

  /// Permite crear una copia del modelo con ciertos campos modificados.
  ProfessorModel copyWith({
    String? id,
    String? name,
    String? email,
    bool? active,
  }) {
    return ProfessorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessorModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          active == other.active;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ email.hashCode ^ active.hashCode;

  @override
  String toString() {
    return 'ProfessorModel(id: $id, name: $name, email: $email, active: $active)';
  }
}
