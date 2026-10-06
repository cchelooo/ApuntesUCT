import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';

abstract class MaterialsRepository {
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
    int page = 1,
    int pageSize = 10,
  });

  Future<List<String>> getAvailableSubjects();

  Future<MaterialDetail> getMaterialDetail(String id);
}
