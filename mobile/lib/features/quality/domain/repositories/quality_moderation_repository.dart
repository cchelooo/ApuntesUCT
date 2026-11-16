import '../../../materials/domain/models/material_requests.dart';
import '../models/moderation_material_detail.dart';
import '../models/pending_moderation_item.dart';

/// Indica que el material solicitado no existe o ya no está pendiente de revisión.
class ModerationMaterialNotFoundException implements Exception {
  const ModerationMaterialNotFoundException(this.materialId);

  final String materialId;

  @override
  String toString() =>
      'ModerationMaterialNotFoundException: material $materialId no encontrado.';
}

/// Contrato de dominio para consultar y revisar materiales en Quality (#409, #410).
abstract class QualityModerationRepository {
  /// Consulta una página de materiales pendientes de moderación.
  Future<PendingModerationPage> listPendingModeration({
    int page = 1,
    int pageSize = 10,
  });

  /// Obtiene el detalle privado de un material pendiente para moderación (#410).
  Future<ModerationMaterialDetail> getPendingMaterialDetail(String materialId);

  /// Descarga el binario autorizado del material pendiente vía Gateway (#410).
  Future<MaterialDownload> downloadPendingMaterial(
    String materialId, {
    String? versionId,
  });
}
