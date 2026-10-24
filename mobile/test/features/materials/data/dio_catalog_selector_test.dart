import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_catalog_selector_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contratos de Catalog usados por los selectores del formulario (#287).
void main() {
  group('CatalogSelectorRepository (#287)', () {
    test('universidades: lista directa con UUID reales', () async {
      String? capturedPath;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.path;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'id': '11111111-1111-4111-8111-111111111111',
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
      final repo = CatalogSelectorRepository(ApiClient(customDio: dio));

      final universities = await repo.listUniversities();

      expect(capturedPath, '/catalog/universities');
      expect(universities, hasLength(1));
      expect(universities.single.id, '11111111-1111-4111-8111-111111111111');
    });

    test('carreras: envía universityId como query param', () async {
      Map<String, dynamic>? capturedQuery;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedQuery = Map<String, dynamic>.from(
                options.queryParameters,
              );
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': [
                      {
                        'id': '33333333-3333-4333-8333-333333333333',
                        'universityId': '11111111-1111-4111-8111-111111111111',
                        'name': 'Ingeniería Civil en Informática',
                        'code': 'ICI',
                        'active': true,
                      },
                      {'id': 'corrupto'},
                    ],
                  },
                ),
              );
            },
          ),
        );
      final repo = CatalogSelectorRepository(ApiClient(customDio: dio));

      final careers = await repo.listCareers(
        universityId: '11111111-1111-4111-8111-111111111111',
      );

      expect(capturedQuery, {
        'universityId': '11111111-1111-4111-8111-111111111111',
      });
      // El elemento corrupto se omite sin romper el listado.
      expect(careers, hasLength(1));
      expect(careers.single.universityId, contains('11111111'));
    });

    test(
      'asignaturas y profesores aceptan envoltorio data y lista directa',
      () async {
        var calls = 0;
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                calls++;
                if (options.path.endsWith('subjects')) {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      statusCode: 200,
                      data: [
                        {
                          'id': '66666666-6666-4666-8666-666666666666',
                          'code': 'INF-2202',
                          'name': 'Bases de Datos',
                        },
                      ],
                    ),
                  );
                } else {
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      statusCode: 200,
                      data: {
                        'data': [
                          {
                            'id': '77777777-7777-4777-8777-777777777777',
                            'name': 'Nelson Mellado',
                            'email': 'nmellado@uct.cl',
                            'active': true,
                          },
                        ],
                      },
                    ),
                  );
                }
              },
            ),
          );
        final repo = CatalogSelectorRepository(ApiClient(customDio: dio));

        final subjects = await repo.listSubjects(careerId: 'career-uuid');
        final professors = await repo.listProfessors(subjectId: 'subject-uuid');

        expect(calls, 2);
        expect(subjects.single.name, 'Bases de Datos');
        expect(professors.single.email, 'nmellado@uct.cl');
      },
    );
  });
}
