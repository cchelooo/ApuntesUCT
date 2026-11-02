import '../domain/models/academic_reference.dart';
import '../domain/models/material_detail.dart';
import '../domain/models/material_summary.dart';

/// Traduce el `data` del 201 de POST /materials (CreateMaterialDto) al
/// dominio Mobile (issue #285).
///
/// No reutiliza `MaterialSummary.fromJson`: el contrato devuelve `year`
/// como cadena, expone `type`/`status` directos y `fileSize` en vez de
/// `fileSizeBytes`. Falla con [FormatException] si faltan id o título.
MaterialDetail materialDetailFromUploadResponse(
  Map<String, dynamic> data,
) {
  AcademicReference? reference(String key) {
    final id = data[key];
    if (id == null) return null;
    final text = id.toString().trim();
    if (text.isEmpty) return null;
    return AcademicReference(id: text);
  }

  final rawId = data['id']?.toString().trim() ?? '';
  if (rawId.isEmpty) {
    throw const FormatException('La respuesta de subida no trae id.');
  }
  final rawTitle = data['title']?.toString().trim() ?? '';
  if (rawTitle.isEmpty) {
    throw const FormatException('La respuesta de subida no trae título.');
  }

  final rawSize = data['fileSize'];
  final fileSizeBytes = rawSize is num
      ? rawSize.toInt()
      : int.tryParse('${rawSize ?? ''}') ?? 0;

  final createdAt = DateTime.tryParse('${data['createdAt'] ?? ''}');

  final summary = MaterialSummary(
    id: rawId,
    title: rawTitle,
    description: '${data['description'] ?? ''}',
    university: reference('universityId'),
    career: reference('careerId'),
    subject: reference('subjectId'),
    professorReference: reference('professorId'),
    subjectName: 'General',
    careerName: 'General',
    fileType: '${data['mimeType'] ?? ''}',
    academicYear: int.tryParse('${data['year'] ?? ''}'),
    materialType: '${data['type'] ?? ''}',
    status: '${data['status'] ?? 'UNKNOWN'}',
    createdAt: createdAt,
  );

  return MaterialDetail(
    summary: summary,
    fileSizeBytes: fileSizeBytes,
  );
}
