import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/academic_hierarchy_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_catalog_selector_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/search_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/materials_discovery_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_discovery_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:apuntesuct_mobile/models/career_model.dart';
import 'package:apuntesuct_mobile/models/professor_model.dart';
import 'package:apuntesuct_mobile/models/subject_model.dart';
import 'package:apuntesuct_mobile/models/university_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class CapturingMaterialsRepository implements MaterialsRepository {
  final List<Map<String, dynamic>> recordedCalls = [];
  List<MaterialSummary> Function(Map<String, dynamic> params)? responseHandler;

  CapturingMaterialsRepository({this.responseHandler});

  @override
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
    String? universityId,
    String? careerId,
    String? subjectId,
    String? professorId,
    int? year,
    String? type,
    int page = 1,
    int pageSize = 10,
  }) async {
    final callParams = <String, dynamic>{
      'query': query,
      'subject': subject,
      'universityId': universityId,
      'careerId': careerId,
      'subjectId': subjectId,
      'professorId': professorId,
      'year': year,
      'type': type,
      'page': page,
      'pageSize': pageSize,
    };
    recordedCalls.add(callParams);

    if (responseHandler != null) {
      return responseHandler!(callParams);
    }
    return [
      MaterialSummary(
        id: 'mat-test-1',
        title: 'Material Filtrado Test',
        subjectName: subject ?? 'Cálculo I',
        authorName: 'Docente Prueba',
        careerName: 'Ingeniería Civil Informática',
        fileType: 'pdf',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<List<String>> getAvailableSubjects() async => ['Cálculo I'];

  @override
  Future<MaterialDetail> getMaterialDetail(String id) async =>
      throw UnimplementedError();
}

class CapturingSearchRepository implements SearchRepository {
  final List<MaterialSearchQuery> recordedQueries = [];
  MaterialPage Function(MaterialSearchQuery query, int page, int pageSize)?
  onSearch;

  CapturingSearchRepository({this.onSearch});

  @override
  Future<MaterialPage> search(
    MaterialSearchQuery query, {
    int page = 1,
    int pageSize = 10,
    CancelToken? cancelToken,
  }) async {
    recordedQueries.add(query);
    if (onSearch != null) {
      return onSearch!(query, page, pageSize);
    }
    return MaterialPage(items: const [], total: 0, page: 1, pageSize: 10);
  }
}

class _DummyMaterialRepository implements MaterialRepository {
  @override
  Future<MaterialPage> list({int page = 1, int pageSize = 10}) =>
      throw UnimplementedError();
  @override
  Future<MaterialDetail> getDetail(String materialId) =>
      throw UnimplementedError();
  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) =>
      throw UnimplementedError();
  @override
  Future<MaterialDownload> download(String materialId, {String? versionId}) =>
      throw UnimplementedError();
  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) => throw UnimplementedError();
}

class _DummyCatalogSelectorRepository implements CatalogSelectorRepository {
  @override
  Future<List<CareerModel>> listCareers({String? universityId}) =>
      throw UnimplementedError();

  @override
  Future<List<ProfessorModel>> listProfessors({String? subjectId}) =>
      throw UnimplementedError();

  @override
  Future<List<SubjectModel>> listSubjects({String? careerId}) =>
      throw UnimplementedError();

  @override
  Future<List<UniversityModel>> listUniversities() =>
      throw UnimplementedError();
}

void main() {
  Widget buildApp({
    required MaterialsRepository materialsRepo,
    IAcademicHierarchyRepository? hierarchyRepo,
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const MaterialDiscoveryScreen(),
        ),
        GoRoute(
          path: '/materials/:id',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Detalle de Material')),
            body: Center(
              child: ElevatedButton(
                key: const Key('back_to_discovery_button'),
                onPressed: () => context.pop(),
                child: const Text('Volver'),
              ),
            ),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        materialsRepositoryProvider.overrideWithValue(materialsRepo),
        if (hierarchyRepo != null)
          academicHierarchyRepositoryProvider.overrideWithValue(hierarchyRepo),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('Issue #294 — Conexión de Filtros Jerárquicos con Resultados Reales', () {
    test('DioMaterialsDiscoveryRepository propaga universityId, careerId, subjectId, professorId, year y type a MaterialSearchQuery', () async {
      final searchRepo = CapturingSearchRepository();
      final discoveryRepo = DioMaterialsDiscoveryRepository(
        searchRepo: searchRepo,
        materialRepo: _DummyMaterialRepository(),
        catalogRepo: _DummyCatalogSelectorRepository(),
      );

      await discoveryRepo.getMaterials(
        query: 'apunte álgebra',
        universityId: 'uni-uct-01',
        careerId: 'car-inf-02',
        subjectId: 'sub-alg-03',
        professorId: 'prof-mun-04',
        year: 2026,
        type: 'apunte',
        page: 1,
        pageSize: 10,
      );

      expect(searchRepo.recordedQueries.length, 1);
      final query = searchRepo.recordedQueries.first;
      expect(query.text, 'apunte álgebra');
      expect(query.universityId, 'uni-uct-01');
      expect(query.careerId, 'car-inf-02');
      expect(query.subjectId, 'sub-alg-03');
      expect(query.professorId, 'prof-mun-04');
      expect(query.year, 2026);
      expect(query.type, 'apunte');
    });

    testWidgets(
      'Criterio 1: Combinación válida envía sus IDs correctos al provider de resultados',
      (WidgetTester tester) async {
        final capturingRepo = CapturingMaterialsRepository();
        await tester.pumpWidget(buildApp(materialsRepo: capturingRepo));
        await tester.pumpAndSettle();

        // 1. Aplicar combinación académica válida con 6 niveles
        final element = tester.element(find.byType(MaterialDiscoveryScreen));
        final container = ProviderScope.containerOf(element);

        await container
            .read(discoveryMaterialsProvider.notifier)
            .applyHierarchyFilters(
              universityId: 'uni-uct-01',
              careerId: 'car-inf-02',
              subjectId: 'sub-calc-03',
              professorId: 'prof-roberto-04',
              year: 2026,
              type: 'certamen',
              universityName: 'Universidad Católica de Temuco',
              careerName: 'Ingeniería Civil Informática',
              subjectName: 'Cálculo I',
              professorName: 'Dr. Roberto Muñoz',
            );
        await tester.pumpAndSettle();

        // Verificar que la última llamada a getMaterials contiene todos los IDs
        final lastCall = capturingRepo.recordedCalls.last;
        expect(lastCall['universityId'], 'uni-uct-01');
        expect(lastCall['careerId'], 'car-inf-02');
        expect(lastCall['subjectId'], 'sub-calc-03');
        expect(lastCall['professorId'], 'prof-roberto-04');
        expect(lastCall['year'], 2026);
        expect(lastCall['type'], 'certamen');
        expect(lastCall['page'], 1);

        // Se muestra la tarjeta de resultado
        expect(find.byType(MaterialSummaryCard), findsOneWidget);
        expect(find.text('Material Filtrado Test'), findsOneWidget);
      },
    );

    testWidgets(
      'Criterio 2: Cambiar un nivel superior limpia filtros incompatibles y reinicia paginación a página 1',
      (WidgetTester tester) async {
        final capturingRepo = CapturingMaterialsRepository();
        await tester.pumpWidget(buildApp(materialsRepo: capturingRepo));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(MaterialDiscoveryScreen));
        final container = ProviderScope.containerOf(element);
        final notifier = container.read(discoveryMaterialsProvider.notifier);

        // 1. Configurar jerarquía completa y simular avance a página 2
        await notifier.applyHierarchyFilters(
          universityId: 'uni-uct-01',
          careerId: 'car-inf-02',
          subjectId: 'sub-calc-03',
          professorId: 'prof-roberto-04',
          year: 2026,
          type: 'apunte',
          universityName: 'UCT',
          careerName: 'Informática',
          subjectName: 'Cálculo I',
          professorName: 'Dr. Roberto',
        );
        await tester.pumpAndSettle();

        // Simular que el estado estaba en página 2
        notifier.state = notifier.state.copyWith(page: 2);
        expect(container.read(discoveryMaterialsProvider).page, 2);

        // 2. Cambiar universidad a UFRO: debe limpiar carrera, ramo y profesor, y reiniciar paginación a 1
        await notifier.setUniversity('uni-ufro-02', universityName: 'UFRO');
        await tester.pumpAndSettle();

        final stateAfterUniChange = container.read(discoveryMaterialsProvider);
        expect(stateAfterUniChange.selectedUniversityId, 'uni-ufro-02');
        expect(stateAfterUniChange.selectedCareerId, isNull);
        expect(stateAfterUniChange.selectedSubjectId, isNull);
        expect(stateAfterUniChange.selectedProfessorId, isNull);
        expect(stateAfterUniChange.page, 1);
        expect(
          stateAfterUniChange.selectedYear,
          2026,
        ); // Preserva año independiente
        expect(stateAfterUniChange.selectedType, 'apunte'); // Preserva tipo

        // Verificar llamada al repositorio
        final lastCallUni = capturingRepo.recordedCalls.last;
        expect(lastCallUni['universityId'], 'uni-ufro-02');
        expect(lastCallUni['careerId'], isNull);
        expect(lastCallUni['subjectId'], isNull);
        expect(lastCallUni['professorId'], isNull);
        expect(lastCallUni['page'], 1);

        // 3. Cambiar carrera limpia ramo y profesor
        await notifier.applyHierarchyFilters(
          universityId: 'uni-uct-01',
          careerId: 'car-inf-02',
          subjectId: 'sub-calc-03',
          professorId: 'prof-roberto-04',
        );
        await notifier.setCareer('car-civil-03', careerName: 'Obras Civiles');
        await tester.pumpAndSettle();

        final stateAfterCareerChange = container.read(
          discoveryMaterialsProvider,
        );
        expect(stateAfterCareerChange.selectedCareerId, 'car-civil-03');
        expect(stateAfterCareerChange.selectedSubjectId, isNull);
        expect(stateAfterCareerChange.selectedProfessorId, isNull);
        expect(stateAfterCareerChange.page, 1);
      },
    );

    testWidgets(
      'Criterio 3: Combinación vacía muestra EmptyState y acción para limpiar filtros',
      (WidgetTester tester) async {
        final capturingRepo = CapturingMaterialsRepository(
          responseHandler: (_) => [], // Sin coincidencias
        );
        await tester.pumpWidget(buildApp(materialsRepo: capturingRepo));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(MaterialDiscoveryScreen));
        final container = ProviderScope.containerOf(element);

        await container
            .read(discoveryMaterialsProvider.notifier)
            .applyHierarchyFilters(
              universityId: 'uni-uct-01',
              careerId: 'car-inf-02',
              subjectId: 'sub-calc-03',
              subjectName: 'Cálculo Avanzado',
            );
        await tester.pumpAndSettle();

        // Debe presentar EmptyState indicando que no hay coincidencias
        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Sin coincidencias'), findsOneWidget);
        expect(
          find.textContaining(
            'No encontramos materiales en "Cálculo Avanzado"',
          ),
          findsOneWidget,
        );
        expect(find.text('Limpiar filtros y búsqueda'), findsOneWidget);

        // Pulsar botón de limpiar filtros reinicia estado
        await tester.tap(find.text('Limpiar filtros y búsqueda'));
        await tester.pumpAndSettle();

        final stateAfterClear = container.read(discoveryMaterialsProvider);
        expect(stateAfterClear.hasHierarchyFilters, isFalse);
        expect(stateAfterClear.page, 1);
      },
    );

    testWidgets(
      'Criterio 4: Fallo de API expone ErrorState con reintento reproducible',
      (WidgetTester tester) async {
        var throwError = true;
        final capturingRepo = CapturingMaterialsRepository(
          responseHandler: (_) {
            if (throwError) {
              throw Exception('Gateway 502 Bad Gateway');
            }
            return [
              MaterialSummary(
                id: 'mat-recovered-1',
                title: 'Material Recuperado Tras Error',
                subjectName: 'Cálculo I',
                authorName: 'Docente',
                careerName: 'Informática',
                fileType: 'pdf',
                createdAt: DateTime(2026, 1, 1),
              ),
            ];
          },
        );

        await tester.pumpWidget(buildApp(materialsRepo: capturingRepo));
        await tester.pumpAndSettle();

        // Se muestra ErrorState con el mensaje de error correspondiente
        expect(find.byType(ErrorState), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);

        // Al presionar reintentar tras resolver el error, recupera los materiales
        throwError = false;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorState), findsNothing);
        expect(find.byType(MaterialSummaryCard), findsOneWidget);
        expect(find.text('Material Recuperado Tras Error'), findsOneWidget);
      },
    );

    testWidgets(
      'Criterio 5: Los filtros aplicados permanecen visibles al volver desde el detalle',
      (WidgetTester tester) async {
        final capturingRepo = CapturingMaterialsRepository();
        await tester.pumpWidget(buildApp(materialsRepo: capturingRepo));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(MaterialDiscoveryScreen));
        final container = ProviderScope.containerOf(element);

        // Aplicar filtros jerárquicos
        await container
            .read(discoveryMaterialsProvider.notifier)
            .applyHierarchyFilters(
              universityId: 'uni-uct-01',
              careerId: 'car-inf-02',
              subjectId: 'sub-calc-03',
              year: 2026,
              type: 'certamen',
              universityName: 'Universidad Católica de Temuco',
              careerName: 'Ingeniería Civil Informática',
              subjectName: 'Cálculo I',
            );
        await tester.pumpAndSettle();

        // Validar que los chips activos están visibles
        expect(find.byKey(const Key('active_chip_university')), findsOneWidget);
        expect(find.byKey(const Key('active_chip_career')), findsOneWidget);
        expect(find.byKey(const Key('active_chip_subject')), findsOneWidget);
        expect(find.byKey(const Key('active_chip_year')), findsOneWidget);
        expect(find.byKey(const Key('active_chip_type')), findsOneWidget);

        // Navegar a la pantalla de detalle de material
        await tester.tap(find.byType(MaterialSummaryCard));
        await tester.pumpAndSettle();

        expect(find.text('Detalle de Material'), findsOneWidget);
        expect(
          find.byKey(const Key('back_to_discovery_button')),
          findsOneWidget,
        );

        // Volver (pop) a la pantalla de descubrimiento
        await tester.tap(find.byKey(const Key('back_to_discovery_button')));
        await tester.pumpAndSettle();

        // Los chips de los filtros aplicados siguen presentes y visibles
        expect(find.byKey(const Key('active_chip_university')), findsOneWidget);
        expect(find.byKey(const Key('active_chip_career')), findsOneWidget);
        expect(find.byKey(const Key('active_chip_subject')), findsOneWidget);
        expect(find.byKey(const Key('active_chip_year')), findsOneWidget);
        expect(find.byKey(const Key('active_chip_type')), findsOneWidget);
        expect(find.text('Universidad Católica de Temuco'), findsOneWidget);
        expect(find.text('Ingeniería Civil Informática'), findsOneWidget);
        expect(find.text('Cálculo I'), findsWidgets);
      },
    );
  });
}
