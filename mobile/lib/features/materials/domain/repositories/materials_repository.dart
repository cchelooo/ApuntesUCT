import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';

/// Lanzada cuando el ID solicitado no corresponde a ningún material.
/// Permite a la ruta /materials/:id mostrar «no encontrado» en lugar de
/// un detalle ajeno o una pantalla en blanco.
class MaterialNotFoundException implements Exception {
  final String materialId;

  const MaterialNotFoundException(this.materialId);

  @override
  String toString() => 'MaterialNotFoundException: $materialId no encontrado.';
}

abstract class MaterialsRepository {
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
    int page = 1,
    int pageSize = 10,
  });

  Future<List<String>> getAvailableSubjects();

  /// Resuelve el detalle por [id] o lanza [MaterialNotFoundException].
  Future<MaterialDetail> getMaterialDetail(String id);
}
