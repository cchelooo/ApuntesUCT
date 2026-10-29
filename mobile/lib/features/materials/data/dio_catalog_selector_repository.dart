import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Acceso a los listados de selectores académicos de Catalog (#287).
///
/// Usa los endpoints dedicados vía gateway (`GET /catalog/universities`,
/// `careers?universityId=`, `subjects?careerId=`, `professors?subjectId=`) para
/// que el formulario de subida envíe UUID reales existentes en Catalog en vez
/// de referencias ficticias (antes `subj-eda-uuid` → 400
/// «subjectId debe ser un UUID válido de Catalog»).
final catalogSelectorRepositoryProvider =
    Provider<CatalogSelectorRepository>((ref) {
      return CatalogSelectorRepository(ref.watch(apiclientProvider));
    });

class CatalogSelectorRepository {
  final ApiClient _apiClient;

  CatalogSelectorRepository(this._apiClient);

  Future<List<UniversityModel>> listUniversities() =>
      _getList('/catalog/universities', UniversityModel.fromJson);

  Future<List<CareerModel>> listCareers({String? universityId}) => _getList(
    '/catalog/careers',
    CareerModel.fromJson,
    query: universityId == null
        ? null
        : {'universityId': universityId},
  );

  Future<List<SubjectModel>> listSubjects({String? careerId}) => _getList(
    '/catalog/subjects',
    SubjectModel.fromJson,
    query: careerId == null ? null : {'careerId': careerId},
  );

  Future<List<ProfessorModel>> listProfessors({String? subjectId}) => _getList(
    '/catalog/professors',
    ProfessorModel.fromJson,
    query: subjectId == null ? null : {'subjectId': subjectId},
  );

  /// Acepta tanto la lista directa como el envoltorio `{data: [...]}`.
  /// Los elementos inválidos se omiten en vez de romper todo el listado.
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
          // Elemento corrupto: se omite sin invalidar el resto.
        }
      }
      return items;
    } on DioException {
      rethrow;
    }
  }
}
