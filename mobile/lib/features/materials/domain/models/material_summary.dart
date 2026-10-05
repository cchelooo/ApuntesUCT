import 'academic_reference.dart';
import 'material_json.dart';
import 'material_status.dart';

class MaterialSummary {
  final String id;
  final String title;
  final String description;
  final String authorName;
  final String? uploaderId;
  final AcademicReference? university;
  final AcademicReference? career;
  final AcademicReference? subject;
  final AcademicReference? professorReference;
  final String _subjectName;
  final String _careerName;
  final String? _professor;
  final String fileType;
  final int? academicYear;
  final String materialType;
  final String status;
  final int downloadCount;
  final double rating;
  final DateTime? createdAt;

  // Conserva los parámetros usados por las tarjetas y fixtures de #284/#283.
  const MaterialSummary({
    required this.id,
    required this.title,
    this.description = '',
    this.authorName = 'Anónimo',
    this.uploaderId,
    this.university,
    this.career,
    this.subject,
    this.professorReference,
    String subjectName = 'General',
    String careerName = 'UCT',
    String? professor,
    this.fileType = '',
    this.academicYear,
    this.materialType = '',
    this.status = 'UNKNOWN',
    this.downloadCount = 0,
    this.rating = 0,
    this.createdAt,
    // Los nombres públicos de estos parámetros mantienen compatible #283/#284.
    // ignore: prefer_initializing_formals
  }) : _subjectName = subjectName,
       // ignore: prefer_initializing_formals
       _careerName = careerName,
       // ignore: prefer_initializing_formals
       _professor = professor;

  String get subjectName => subject?.name ?? _subjectName;
  String get careerName => career?.name ?? _careerName;
  String? get professor => professorReference?.name ?? _professor;
  MaterialStatus get reviewStatus => MaterialStatus.fromJson(status);

  factory MaterialSummary.fromJson(Map<String, dynamic> json) {
    final status = MaterialStatus.fromJson(json['status']);
    return MaterialSummary(
      id: MaterialJson.requiredText(json, 'id'),
      title: MaterialJson.requiredText(json, 'title'),
      description: MaterialJson.text(json, 'description') ?? '',
      authorName:
          MaterialJson.text(json, 'authorName') ??
          MaterialJson.text(json, 'author') ??
          'Anónimo',
      uploaderId: MaterialJson.text(json, 'uploaderId'),
      university: MaterialJson.reference(
        json,
        'universityId',
        'universityName',
      ),
      career: MaterialJson.reference(json, 'careerId', 'careerName'),
      subject: MaterialJson.reference(json, 'subjectId', 'subjectName'),
      professorReference: MaterialJson.reference(
        json,
        'professorId',
        'professor',
      ),
      subjectName:
          MaterialJson.text(json, 'subjectName') ??
          MaterialJson.text(json, 'subject') ??
          'General',
      careerName: MaterialJson.text(json, 'careerName') ?? 'UCT',
      professor: MaterialJson.text(json, 'professor'),
      fileType: MaterialJson.text(json, 'fileType') ?? '',
      academicYear:
          MaterialJson.integer(json, 'academicYear', min: 1) ??
          MaterialJson.integer(json, 'year', min: 1),
      materialType:
          MaterialJson.text(json, 'materialType') ??
          MaterialJson.text(json, 'type') ??
          '',
      status: status == MaterialStatus.unknown
          ? (MaterialJson.text(json, 'status') ?? 'UNKNOWN')
          : status.code,
      downloadCount: MaterialJson.integer(json, 'downloadCount') ?? 0,
      rating: MaterialJson.number(json, 'rating') ?? 0,
      createdAt: MaterialJson.timestamp(json, 'createdAt'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'authorName': authorName,
    if (uploaderId != null) 'uploaderId': uploaderId,
    if (university != null) 'universityId': university!.id,
    if (university?.name != null) 'universityName': university!.name,
    if (career != null) 'careerId': career!.id,
    if (subject != null) 'subjectId': subject!.id,
    if (professorReference != null) 'professorId': professorReference!.id,
    if (subject == null || subject!.name != null) 'subjectName': subjectName,
    if (career == null || career!.name != null) 'careerName': careerName,
    if (professor != null) 'professor': professor,
    'fileType': fileType,
    if (academicYear != null) 'academicYear': academicYear,
    'materialType': materialType,
    'status': reviewStatus == MaterialStatus.unknown
        ? status
        : reviewStatus.code,
    'downloadCount': downloadCount,
    'rating': rating,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}
