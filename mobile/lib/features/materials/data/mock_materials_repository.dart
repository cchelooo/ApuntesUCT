import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_fixtures.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';

class MockMaterialsRepository implements MaterialsRepository {
  final List<MaterialSummary> _dataset;
  final List<String> _subjectsCatalog;
  final Duration delay;

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
       _subjectsCatalog = customSubjects ?? defaultAcademicSubjects;

  @override
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
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
    return MaterialFixtures.sampleDetail1;
  }
}
