import 'package:apuntesuct_mobile/core/config/api_config.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/data/gateway_academic_hierarchy_repository.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GatewayAcademicHierarchyRepository (Issue #288)', () {
    test('Proveedor por defecto utiliza ApiClient y Gateway baseUrl', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(academicHierarchyRepositoryProvider);
      expect(repo, isA<GatewayAcademicHierarchyRepository>());
    });

    test('fetchUniversities consulta GET /catalog/universities vía Gateway', () async {
      String? capturedPath;
      String? capturedMethod;

      final dio = Dio(BaseOptions(baseUrl: ApiConfig.gatewayBaseUrl))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.path;
              capturedMethod = options.method;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 'uct-uuid-1111',
                      'name': 'Universidad Católica de Temuco',
                      'code': 'UCT',
                      'active': true,
                    },
                    {
                      'id': 'ufro-uuid-2222',
                      'name': 'Universidad de La Frontera',
                      'code': 'UFRO',
                      'active': true,
                    },
                  ],
                ),
              );
            },
          ),
        );

      final repo = GatewayAcademicHierarchyRepository(ApiClient(customDio: dio));
      final universities = await repo.fetchUniversities();

      expect(capturedMethod, 'GET');
      expect(capturedPath, '/catalog/universities');
      expect(universities, hasLength(2));
      expect(universities.first.name, 'Universidad Católica de Temuco');
      expect(universities.last.code, 'UFRO');
    });

    test('fetchCareersByUniversity consulta GET /catalog/careers con universityId', () async {
      String? capturedPath;
      Map<String, dynamic>? capturedQuery;

      final dio = Dio(BaseOptions(baseUrl: ApiConfig.gatewayBaseUrl))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.path;
              capturedQuery = Map<String, dynamic>.from(options.queryParameters);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': [
                      {
                        'id': 'career-ici-uuid',
                        'universityId': 'uct-uuid-1111',
                        'name': 'Ingeniería Civil en Informática',
                        'code': 'ICI',
                        'active': true,
                      },
                      {'invalid': 'sin id'},
                    ],
                  },
                ),
              );
            },
          ),
        );

      final repo = GatewayAcademicHierarchyRepository(ApiClient(customDio: dio));
      final careers = await repo.fetchCareersByUniversity('uct-uuid-1111');

      expect(capturedPath, '/catalog/careers');
      expect(capturedQuery, {'universityId': 'uct-uuid-1111'});
      // Elemento corrupto se omite sin romper el listado
      expect(careers, hasLength(1));
      expect(careers.single.name, 'Ingeniería Civil en Informática');
    });

    test('fetchCareersByUniversity con ID vacío retorna lista vacía sin hacer petición HTTP', () async {
      var httpCalls = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              httpCalls++;
              handler.next(options);
            },
          ),
        );

      final repo = GatewayAcademicHierarchyRepository(ApiClient(customDio: dio));
      final careers = await repo.fetchCareersByUniversity('   ');

      expect(httpCalls, 0);
      expect(careers, isEmpty);
    });

    test('fetchSubjectsByCareer consulta GET /catalog/subjects con careerId', () async {
      String? capturedPath;
      Map<String, dynamic>? capturedQuery;

      final dio = Dio(BaseOptions(baseUrl: ApiConfig.gatewayBaseUrl))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.path;
              capturedQuery = Map<String, dynamic>.from(options.queryParameters);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 'sub-bd-uuid',
                      'careerId': 'career-ici-uuid',
                      'name': 'Bases de Datos',
                      'code': 'INF-2202',
                    },
                  ],
                ),
              );
            },
          ),
        );

      final repo = GatewayAcademicHierarchyRepository(ApiClient(customDio: dio));
      final subjects = await repo.fetchSubjectsByCareer('career-ici-uuid');

      expect(capturedPath, '/catalog/subjects');
      expect(capturedQuery, {'careerId': 'career-ici-uuid'});
      expect(subjects, hasLength(1));
      expect(subjects.single.code, 'INF-2202');
    });

    test('fetchProfessorsBySubject consulta GET /catalog/professors con subjectId', () async {
      String? capturedPath;
      Map<String, dynamic>? capturedQuery;

      final dio = Dio(BaseOptions(baseUrl: ApiConfig.gatewayBaseUrl))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.path;
              capturedQuery = Map<String, dynamic>.from(options.queryParameters);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 'prof-1-uuid',
                      'name': 'Dr. Alan Turing',
                      'email': 'aturing@uct.cl',
                      'active': true,
                    },
                  ],
                ),
              );
            },
          ),
        );

      final repo = GatewayAcademicHierarchyRepository(ApiClient(customDio: dio));
      final professors = await repo.fetchProfessorsBySubject('sub-bd-uuid');

      expect(capturedPath, '/catalog/professors');
      expect(capturedQuery, {'subjectId': 'sub-bd-uuid'});
      expect(professors, hasLength(1));
      expect(professors.single.name, 'Dr. Alan Turing');
    });

    test('Propaga excepciones de Dio para que Riverpod gestione el AsyncError', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 502,
                    statusMessage: 'Bad Gateway - Catalog Service no disponible',
                  ),
                ),
              );
            },
          ),
        );

      final repo = GatewayAcademicHierarchyRepository(ApiClient(customDio: dio));

      expect(
        () => repo.fetchUniversities(),
        throwsA(isA<DioException>()),
      );
    });

    test('Formato JSON no reconocido lanza FormatException', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: 'respuesta no json',
                ),
              );
            },
          ),
        );

      final repo = GatewayAcademicHierarchyRepository(ApiClient(customDio: dio));

      expect(
        () => repo.fetchUniversities(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AcademicHierarchyNotifier integrado con GatewayAcademicHierarchyRepository (#288)', () {
    test('Carga universidades vía Gateway y maneja ciclo de estados loading/éxito', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.gatewayBaseUrl))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': 'uct-uuid-1',
                      'name': 'Universidad Católica de Temuco',
                      'code': 'UCT',
                      'active': true,
                    },
                  ],
                ),
              );
            },
          ),
        );

      final container = ProviderContainer(
        overrides: [
          apiclientProvider.overrideWithValue(ApiClient(customDio: dio)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(academicHierarchyProvider.notifier);
      await notifier.loadUniversities();

      final state = container.read(academicHierarchyProvider);
      expect(state.isLoadingUniversities, isFalse);
      expect(state.errorUniversities, isNull);
      expect(state.universities, hasLength(1));
      expect(state.universities.single.id, 'uct-uuid-1');
    });

    test('Maneja error de red vía Gateway y permite reintento exitoso', () async {
      var fail = true;
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.gatewayBaseUrl))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (fail) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.connectionError,
                    message: 'Fallo de conexión con el Gateway',
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: [
                      {
                        'id': 'uct-uuid-1',
                        'name': 'Universidad Católica de Temuco',
                        'code': 'UCT',
                        'active': true,
                      },
                    ],
                  ),
                );
              }
            },
          ),
        );

      final container = ProviderContainer(
        overrides: [
          apiclientProvider.overrideWithValue(ApiClient(customDio: dio)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(academicHierarchyProvider.notifier);

      // Intento 1: Falla
      await notifier.loadUniversities();
      var state = container.read(academicHierarchyProvider);
      expect(state.errorUniversities, isNotNull);
      expect(state.universities, isEmpty);

      // Intento 2: Reintento exitoso
      fail = false;
      await notifier.retryUniversities();
      state = container.read(academicHierarchyProvider);
      expect(state.errorUniversities, isNull);
      expect(state.universities, hasLength(1));
    });
  });
}

