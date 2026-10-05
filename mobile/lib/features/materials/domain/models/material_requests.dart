import 'academic_reference.dart';

/// Entradas del dominio, sin archivos de Flutter ni multipart de Dio.
sealed class MaterialSource {
  const MaterialSource();
}

class LocalMaterialFile extends MaterialSource {
  final String fileName;
  final String mimeType;
  final List<int> bytes;

  LocalMaterialFile({
    required this.fileName,
    required this.mimeType,
    required List<int> bytes,
  }) : bytes = List.unmodifiable(bytes);
}

class ExternalMaterialLink extends MaterialSource {
  final Uri url;
  const ExternalMaterialLink(this.url);
}

class UploadMaterialRequest {
  final String title;
  final String? description;
  final AcademicReference university;
  final AcademicReference career;
  final AcademicReference subject;
  final AcademicReference? professor;
  final int year;
  final String type;
  final MaterialSource source;

  const UploadMaterialRequest({
    required this.title,
    this.description,
    required this.university,
    required this.career,
    required this.subject,
    this.professor,
    required this.year,
    required this.type,
    required this.source,
  });
}

class MaterialDownload {
  final String fileName;
  final String mimeType;
  final List<int> bytes;

  MaterialDownload({
    required this.fileName,
    required this.mimeType,
    required List<int> bytes,
  }) : bytes = List.unmodifiable(bytes);
}

class MaterialSearchQuery {
  final String text;
  final String? universityId;
  final String? careerId;
  final String? subjectId;
  final String? professorId;
  final int? year;
  final String? type;

  const MaterialSearchQuery({
    this.text = '',
    this.universityId,
    this.careerId,
    this.subjectId,
    this.professorId,
    this.year,
    this.type,
  });
}
