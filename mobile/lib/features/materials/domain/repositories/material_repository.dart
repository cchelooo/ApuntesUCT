import '../models/material_detail.dart';
import '../models/material_page.dart';
import '../models/material_requests.dart';
import '../models/material_version.dart';

/// Operaciones de Material Service. Sin búsqueda textual ni filtros de Search.
abstract interface class MaterialRepository {
  Future<MaterialPage> list({int page = 1, int pageSize = 10});
  Future<MaterialDetail> getDetail(String materialId);
  Future<MaterialDetail> upload(UploadMaterialRequest request);
  Future<MaterialDownload> download(String materialId, {String? versionId});
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source,
  );
}
