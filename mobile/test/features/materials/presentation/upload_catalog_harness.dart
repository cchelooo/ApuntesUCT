import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_catalog_selectors_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_upload_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// UUID v4 de los fixtures de Catalog para el formulario de subida.
///
/// Son los que el backend acepta (`isUUID` en catalog-http.adapter):
/// los ids ficticios anteriores (`subj-eda-uuid`, `inf-uct-uuid`) caían en
/// 400 «subjectId debe ser un UUID válido de Catalog».
const testUctId = '11111111-1111-4111-8111-111111111111';
const testUfroId = '22222222-2222-4222-8222-222222222222';
const testIciId = '33333333-3333-4333-8333-333333333333';
const testMedvetId = '44444444-4444-4434-8444-444444444444';
const testEdaId = '55555555-5555-4555-8555-555555555555';
const testBdId = '66666666-6666-4666-8666-666666666666';
const testMelladoId = '77777777-7777-4777-8777-777777777777';

/// Acepta UUID v4 (formato que exige Material Service para las referencias).
bool isCatalogUuid(String id) =>
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
        .hasMatch(id);

List<UniversityModel> testUniversities() => [
  UniversityModel(
    id: testUctId,
    name: 'Universidad Católica de Temuco',
    code: 'UCT',
  ),
  UniversityModel(
    id: testUfroId,
    name: 'Universidad de La Frontera',
    code: 'UFRO',
  ),
];

Map<String, List<CareerModel>> testCareersByUniversity() => {
  testUctId: [
    CareerModel(
      id: testIciId,
      universityId: testUctId,
      name: 'Ingeniería Civil en Informática',
      code: 'ICI',
      active: true,
    ),
    CareerModel(
      id: testMedvetId,
      universityId: testUctId,
      name: 'Medicina Veterinaria',
      code: 'MVET',
      active: true,
    ),
  ],
};

Map<String, List<SubjectModel>> testSubjectsByCareer() => {
  testIciId: [
    SubjectModel(
      id: testEdaId,
      code: 'INF-2101',
      name: 'Estructuras de Datos y Algoritmos',
    ),
    SubjectModel(id: testBdId, code: 'INF-2202', name: 'Bases de Datos'),
  ],
};

Map<String, List<ProfessorModel>> testProfessorsBySubject() => {
  testEdaId: [
    ProfessorModel(
      id: testMelladoId,
      name: 'Nelson Mellado',
      email: 'nmellado@uct.cl',
      active: true,
    ),
  ],
};

/// Monta el formulario con los selectores de Catalog sustituidos por
/// fixtures de UUID reales (sin red). Los ids no incluidos resuelven `[]`.
Future<void> pumpUploadScreen(
  WidgetTester tester, {
  Future<MaterialPickedFile?> Function()? pickFile,
  Size surface = const Size(390, 844),
  MaterialRepository? uploadRepository,
  List<UniversityModel>? universities,
  Map<String, List<CareerModel>>? careersByUniversity,
  Map<String, List<SubjectModel>>? subjectsByCareer,
  Map<String, List<ProfessorModel>>? professorsBySubject,
  GoRouter? router,
}) async {
  final unis = universities ?? testUniversities();
  final resolvedCareers = careersByUniversity ?? testCareersByUniversity();
  final resolvedSubjects = subjectsByCareer ?? testSubjectsByCareer();
  final resolvedProfessors = professorsBySubject ?? testProfessorsBySubject();

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (uploadRepository != null)
          dioMaterialRepositoryProvider.overrideWithValue(uploadRepository),
        uploadUniversitiesProvider.overrideWithValue(AsyncData(unis)),
        for (final u in unis)
          uploadCareersProvider(u.id)
              .overrideWithValue(AsyncData(resolvedCareers[u.id] ?? const [])),
        for (final c in resolvedCareers.values.expand((e) => e))
          uploadSubjectsProvider(c.id)
              .overrideWithValue(AsyncData(resolvedSubjects[c.id] ?? const [])),
        for (final s in resolvedSubjects.values.expand((e) => e))
          uploadProfessorsProvider(
            s.id,
          ).overrideWithValue(AsyncData(resolvedProfessors[s.id] ?? const [])),
      ],
      child: router == null
          ? MaterialApp(home: MaterialUploadScreen(pickFile: pickFile))
          : MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}
