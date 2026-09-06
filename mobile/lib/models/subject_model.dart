/// Modelo inmutable que representa una asignatura/ramo en el catálogo académico.
/// Mapea la entidad SUBJECT proveniente de Catalog Service.
class SubjectModel {
  final String id;
  final String code;
  final String name;
  final String? description;

  const SubjectModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
  });

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  /// Serializa el modelo a un mapa JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
    };
  }

  /// Factory para generar una instancia MOCK de ejemplo.
  factory SubjectModel.mock({
    String id = 'subj-integra-iv-uuid',
    String code = 'INF-4101',
    String name = 'Integración de Sistemas IV',
    String? description =
        'Taller integrador de arquitectura de microservicios y desarrollo móvil.',
  }) {
    return SubjectModel(
      id: id,
      code: code,
      name: name,
      description: description,
    );
  }

  /// Lista de asignaturas MOCK para pruebas de UI y listados.
  static List<SubjectModel> mockList() {
    return [
      SubjectModel.mock(
        id: 'subj-integra-iv-uuid',
        code: 'INF-4101',
        name: 'Integración de Sistemas IV',
        description:
            'Taller integrador de arquitectura de microservicios y desarrollo móvil.',
      ),
      SubjectModel.mock(
        id: 'subj-eda-uuid',
        code: 'INF-2101',
        name: 'Estructuras de Datos y Algoritmos',
        description: 'Árboles, grafos, análisis asintótico y algoritmos clásicos.',
      ),
      SubjectModel.mock(
        id: 'subj-bd-uuid',
        code: 'INF-2202',
        name: 'Bases de Datos',
        description: 'Modelo relacional, SQL, normalización y transacciones.',
      ),
      SubjectModel.mock(
        id: 'subj-arq-uuid',
        code: 'INF-3103',
        name: 'Arquitectura de Software',
        description: 'Patrones de diseño, microservicios, DDD y sistemas distribuidos.',
      ),
    ];
  }

  /// Permite crear una copia del modelo con ciertos campos modificados.
  SubjectModel copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          description == other.description;

  @override
  int get hashCode =>
      id.hashCode ^ code.hashCode ^ name.hashCode ^ description.hashCode;

  @override
  String toString() {
    return 'SubjectModel(id: $id, code: $code, name: $name, description: $description)';
  }
}
