import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_fixtures.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';

class MockMaterialsRepository implements MaterialsRepository {
  @override
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
    int page = 1,
    int pageSize = 10,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));

    var results = List<MaterialSummary>.from(MaterialFixtures.sampleSummaries);

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
  Future<MaterialDetail> getMaterialDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return MaterialFixtures.sampleDetail1;
  }
}
