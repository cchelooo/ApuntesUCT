import 'material_detail.dart';
import 'material_summary.dart';

class MaterialFixtures {
  static final sampleSummary1 = MaterialSummary(
    id: 'mat-101',
    title: 'Resumen Certamen 1 - Estructuras de Datos',
    description:
        'Árboles AVL, grafos y análisis asintótico con ejemplos prácticos.',
    authorName: 'Marcelo S.',
    subjectName: 'Estructuras de Datos',
    careerName: 'Ingeniería Civil Informática',
    fileType: 'pdf',
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
  );
}
