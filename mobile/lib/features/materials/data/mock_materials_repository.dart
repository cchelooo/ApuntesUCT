import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_fixtures.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';

class MockMaterialsRepository implements MaterialsRepository {
  final List<MaterialSummary> _dataset;
  final List<String> _subjectsCatalog;
  final Duration delay;
  final bool _isCustomDataset;

  static const List<String> defaultAcademicSubjects = [
    'Cálculo I',
    'Estructuras de Datos',
    'Álgebra Lineal',
    'Física I',
    'Bases de Datos',
  ];

  MockMaterialsRepository({
    List<MaterialSummary>? customDataset,
    List<String>? customSubjects,
    this.delay = Duration.zero,
  }) : _dataset =
           customDataset ??
           List<MaterialSummary>.from(MaterialFixtures.sampleSummaries),
       _subjectsCatalog = customSubjects ?? defaultAcademicSubjects,
       _isCustomDataset = customDataset != null;

  @override
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
    String? universityId,
    String? careerId,
    String? subjectId,
    String? professorId,
    int? year,
    String? type,
    int page = 1,
    int pageSize = 10,
  }) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    var results = List<MaterialSummary>.from(_dataset);

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      results = results
          .where(
            (m) =>
                m.title.toLowerCase().contains(q) ||
                m.subjectName.toLowerCase().contains(q) ||
                m.authorName.toLowerCase().contains(q) ||
                (m.professor?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    if (subject != null && subject.trim().isNotEmpty) {
      results = results.where((m) => m.subjectName == subject).toList();
    } else if (subjectId != null && subjectId.trim().isNotEmpty) {
      final sId = subjectId.trim().toLowerCase();
      final filtered = results
          .where(
            (m) =>
                m.subject?.id.toLowerCase() == sId ||
                m.subjectName.toLowerCase() == sId ||
                m.subjectName.toLowerCase().contains(sId),
          )
          .toList();
      if (_isCustomDataset || filtered.isNotEmpty) {
        results = filtered;
      }
    }

    if (universityId != null && universityId.trim().isNotEmpty) {
      final uId = universityId.trim().toLowerCase();
      final filtered = results
          .where(
            (m) =>
                m.university?.id.toLowerCase() == uId ||
                (m.university?.name?.toLowerCase().contains(uId) ?? false),
          )
          .toList();
      if (_isCustomDataset) {
        results = filtered;
      }
    }

    if (careerId != null && careerId.trim().isNotEmpty) {
      final cId = careerId.trim().toLowerCase();
      final filtered = results
          .where(
            (m) =>
                m.career?.id.toLowerCase() == cId ||
                (m.career?.name?.toLowerCase().contains(cId) ?? false) ||
                m.careerName.toLowerCase().contains(cId),
          )
          .toList();
      if (_isCustomDataset) {
        results = filtered;
      }
    }

    if (professorId != null && professorId.trim().isNotEmpty) {
      final pId = professorId.trim().toLowerCase();
      results = results
          .where(
            (m) =>
                m.professorReference?.id.toLowerCase() == pId ||
                (m.professor?.toLowerCase().contains(pId) ?? false),
          )
          .toList();
    }

    if (year != null) {
      results = results.where((m) => m.academicYear == year).toList();
    }

    if (type != null && type.trim().isNotEmpty) {
      final t = type.trim().toLowerCase();
      results = results
          .where((m) => m.materialType.toLowerCase() == t)
          .toList();
    }

    if (universityId != null && universityId.trim().isNotEmpty) {
      final u = universityId.trim();
      results = results.where((m) => m.university?.id == u).toList();
    }

    if (careerId != null && careerId.trim().isNotEmpty) {
      final c = careerId.trim();
      results = results.where((m) => m.career?.id == c).toList();
    }

    if (subjectId != null && subjectId.trim().isNotEmpty) {
      final s = subjectId.trim();
      results = results.where((m) => m.subject?.id == s).toList();
    }

    if (professorId != null && professorId.trim().isNotEmpty) {
      final p = professorId.trim();
      results = results.where((m) => m.professorReference?.id == p).toList();
    }

    if (year != null) {
      results = results.where((m) => m.academicYear == year).toList();
    }

    if (type != null && type.trim().isNotEmpty) {
      final t = type.trim().toUpperCase();
      results = results.where((m) => m.materialType.toUpperCase() == t).toList();
    }

    final startIndex = (page - 1) * pageSize;
    if (startIndex >= results.length) return [];

    final endIndex = (startIndex + pageSize < results.length)
        ? startIndex + pageSize
        : results.length;

    return results.sublist(startIndex, endIndex);
  }

  @override
  Future<List<String>> getAvailableSubjects() async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    // Catálogo académico independiente
    final subjects = List<String>.from(_subjectsCatalog);
    subjects.sort();
    return subjects;
  }

  @override
  Future<MaterialDetail> getMaterialDetail(String id) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    for (final summary in _dataset) {
      if (summary.id == id) {
        final fixture = MaterialFixtures.detailForId(id);
        if (fixture != null) return fixture;
        return MaterialDetail(summary: summary);
      }
    }
    final fixture = MaterialFixtures.detailForId(id);
    if (fixture != null) return fixture;
    throw MaterialNotFoundException(id);
  }
}
