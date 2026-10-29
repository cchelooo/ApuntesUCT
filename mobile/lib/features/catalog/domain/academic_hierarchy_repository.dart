import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';

/// Contrato que define las operaciones de carga de cada nivel
/// de la jerarquía académica.
///
/// Permite sustituir la fuente de datos en pruebas (mocks, errores de red,
/// respuestas vacías) sin tocar el código de producción.
abstract class IAcademicHierarchyRepository {
  /// Devuelve todas las universidades disponibles.
  Future<List<UniversityModel>> fetchUniversities();

  /// Devuelve las carreras que pertenecen a [universityId].
  Future<List<CareerModel>> fetchCareersByUniversity(String universityId);

  /// Devuelve las asignaturas que pertenecen a [careerId].
  Future<List<SubjectModel>> fetchSubjectsByCareer(String careerId);

  /// Devuelve los profesores asociados a [subjectId].
  Future<List<ProfessorModel>> fetchProfessorsBySubject(String subjectId);
}

// ---------------------------------------------------------------------------
// Implementación Mock (datos en memoria para desarrollo y pruebas)
// ---------------------------------------------------------------------------

/// Implementación de [IAcademicHierarchyRepository] que devuelve datos
/// mock en memoria. No realiza ninguna llamada HTTP real.
class MockAcademicHierarchyRepository implements IAcademicHierarchyRepository {
  @override
  Future<List<UniversityModel>> fetchUniversities() async =>
      UniversityModel.mockList();

  @override
  Future<List<CareerModel>> fetchCareersByUniversity(
    String universityId,
  ) async {
    // Filtra estrictamente por universidad: nunca devuelve carreras de otra
    // institución como fallback (issue: UFRO mostraba carreras de UCT).
    return CareerModel.mockList()
        .where((c) => c.universityId == universityId)
        .toList();
  }

  @override
  Future<List<SubjectModel>> fetchSubjectsByCareer(String careerId) async =>
      SubjectModel.mockList();

  @override
  Future<List<ProfessorModel>> fetchProfessorsBySubject(
    String subjectId,
  ) async =>
      ProfessorModel.mockList();
}

/// Provider de Riverpod para inyectar y sobreescribir el repositorio jerárquico.
final academicHierarchyRepositoryProvider =
    Provider<IAcademicHierarchyRepository>((ref) {
  return MockAcademicHierarchyRepository();
});
