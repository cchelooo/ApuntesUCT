import 'academic_reference.dart';
import 'material_detail.dart';
import 'material_page.dart';
import 'material_summary.dart';
import 'material_version.dart';

class MaterialFixtures {
  // Datos locales para UI; no representan respuestas reales del Backend.
  static final university = AcademicReference(
    id: '00000000-0000-4000-8000-000000000001',
    name: 'Universidad Católica de Temuco',
  );
  static final career = AcademicReference(
    id: '00000000-0000-4000-8000-000000000002',
    name: 'Ingeniería Civil Informática',
  );
  static final subject = AcademicReference(
    id: '00000000-0000-4000-8000-000000000003',
    name: 'Estructuras de Datos',
  );
  static final professor = AcademicReference(
    id: '00000000-0000-4000-8000-000000000004',
    name: 'Dr. Roberto Muñoz',
  );

  static final sampleSummary1 = MaterialSummary(
    id: 'mat-101',
    title: 'Resumen Certamen 1 - Estructuras de Datos',
    description:
        'Árboles AVL, grafos y análisis asintótico con ejemplos prácticos.',
    authorName: 'Marcelo S.',
    subjectName: 'Estructuras de Datos',
    careerName: 'Ingeniería Civil Informática',
    fileType: 'pdf',
    university: university,
    career: career,
    subject: subject,
    professorReference: professor,
    professor: 'Dr. Roberto Muñoz',
    academicYear: 2026,
    materialType: 'certamen',
    status: 'aprobado',
    downloadCount: 42,
    rating: 4.8,
    createdAt: DateTime(2026, 3, 15),
  );

  static final sampleSummary2 = MaterialSummary(
    id: 'mat-102',
    title: 'Guía de Ejercicios Resueltos - Cálculo I',
    description: 'Límites, continuidad y derivadas paso a paso.',
    authorName: 'Yaninna A.',
    subjectName: 'Cálculo I',
    careerName: 'Plan Común Ingeniería',
    fileType: 'pdf',
    professor: 'Mg. Carlos Contreras',
    academicYear: 2025,
    materialType: 'guia',
    status: 'aprobado',
    downloadCount: 88,
    rating: 4.9,
    createdAt: DateTime(2026, 3, 20),
  );

  static List<MaterialSummary> get sampleSummaries => [
    sampleSummary1,
    sampleSummary2,
  ];

  static final sampleDetail1 = MaterialDetail(
    summary: sampleSummary1,
    downloadUrl: 'https://storage.uct.cl/materials/mat-101.pdf',
    fileSizeBytes: 2450000,
    tags: ['Árboles', 'Grafos', 'Complejidad', 'Certamen'],
    viewCount: 156,
    versions: [sampleVersion1],
    currentVersionId: sampleVersion1.id,
  );

  static final sampleVersion1 = MaterialVersion(
    id: 'version-101',
    materialId: sampleSummary1.id,
    versionNumber: 1,
    originalFileName: 'estructuras-de-datos.pdf',
    mimeType: 'application/pdf',
    fileSizeBytes: 2450000,
    storageKey: 'materials/mat-101/v1.pdf',
    createdAt: DateTime.utc(2026, 3, 15),
  );

  static MaterialPage get samplePage => MaterialPage(
    items: sampleSummaries,
    page: 1,
    pageSize: 10,
    total: sampleSummaries.length,
  );
}
