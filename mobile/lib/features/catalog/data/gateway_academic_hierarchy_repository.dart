import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/academic_hierarchy_repository.dart';
import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Proveedor de [IAcademicHierarchyRepository] que conecta los selectores
/// académicos al Catalog Service exclusivamente a través del API Gateway (#288).
final gatewayAcademicHierarchyRepositoryProvider =
    Provider<IAcademicHierarchyRepository>((ref) {
      final apiClient = ref.watch(apiclientProvider);
      return GatewayAcademicHierarchyRepository(apiClient);
    });

/// Implementación de [IAcademicHierarchyRepository] que realiza las consultas
/// de jerarquía académica (universidades, carreras, asignaturas, profesores)
/// exclusivamente a través del API Gateway (`/api/v1/catalog/*`), sin acceder
/// directamente al microservicio Catalog en el puerto 3002.
class GatewayAcademicHierarchyRepository
    implements IAcademicHierarchyRepository {
  final ApiClient _apiClient;

  GatewayAcademicHierarchyRepository(this._apiClient);

  @override
  Future<List<UniversityModel>> fetchUniversities() =>
      _getList('/catalog/universities', UniversityModel.fromJson);

  @override
  Future<List<CareerModel>> fetchCareersByUniversity(String universityId) {
    final trimmed = universityId.trim();
    if (trimmed.isEmpty) return Future.value(const []);
    return _getList(
      '/catalog/careers',
      CareerModel.fromJson,
      query: {'universityId': trimmed},
    );
  }

  @override
  Future<List<SubjectModel>> fetchSubjectsByCareer(String careerId) {
    final trimmed = careerId.trim();
    if (trimmed.isEmpty) return Future.value(const []);
    return _getList(
      '/catalog/subjects',
      SubjectModel.fromJson,
      query: {'careerId': trimmed},
    );
  }

  @override
  Future<List<ProfessorModel>> fetchProfessorsBySubject(String subjectId) {
    final trimmed = subjectId.trim();
    if (trimmed.isEmpty) return Future.value(const []);
    return _getList(
      '/catalog/professors',
      ProfessorModel.fromJson,
      query: {'subjectId': trimmed},
    );
  }

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _apiClient.dio.get(path, queryParameters: query);
      final data = response.data;
      final List<dynamic> raw;
      if (data is List) {
        raw = data;
      } else if (data is Map<String, dynamic> && data['data'] is List) {
        raw = data['data'] as List;
      } else {
        throw const FormatException('Formato de catálogo inválido.');
      }
      final items = <T>[];
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          items.add(parse(Map<String, dynamic>.from(entry)));
        } catch (_) {
          // Omitir elementos corruptos sin invalidar los válidos
        }
      }
      return items;
    } on DioException {
      rethrow;
    }
  }
}
