import '../models/pending_moderation_item.dart';

/// Contrato de dominio para consultar la cola privada de moderación en Quality (#409).
abstract class QualityModerationRepository {
  /// Consulta una página de materiales pendientes de moderación.
  Future<PendingModerationPage> listPendingModeration({
    int page = 1,
    int pageSize = 10,
  });
}
