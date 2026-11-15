import '../models/material_page.dart';

/// Contrato de dominio para consultar la cola privada de revisión de materiales (#409).
abstract class ModerationRepository {
  /// Obtiene una página de materiales pendientes de moderación (`PENDING_REVIEW`).
  Future<MaterialPage> listPending({int page = 1, int pageSize = 10});
}
