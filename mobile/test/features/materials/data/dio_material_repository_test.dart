import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/academic_reference.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_status.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_gateway_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/material_http_adapter.dart';

void main() {
  Map<String, dynamic> fixture() => jsonDecode(
    File('test/fixtures/materials/gateway_create.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final file = LocalMaterialFile(
    fileName: 'apuntes.pdf',
    mimeType: 'application/pdf',
    bytes: utf8.encode('%PDF-1.7\nApuntes 274\n%%EOF'),
  );
  UploadMaterialRequest request({
    MaterialSource? source,
    String type = 'DOCUMENT',
  }) => UploadMaterialRequest(
    title: 'Apuntes de álgebra',
    description: 'Ejercicios resueltos',
    university: AcademicReference(id: 'university-test'),
    career: AcademicReference(id: '55555555-5555-4555-8555-555555555555'),
    subject: AcademicReference(id: '44444444-4444-4444-8444-444444444444'),
    professor: AcademicReference(id: '66666666-6666-4666-8666-666666666666'),
    year: 2026,
    type: type,
    source: source ?? file,
  );
  DioMaterialRepository repository(MaterialHttpAdapter adapter) {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://gateway.example.test/api/v1',
        contentType: Headers.jsonContentType,
        headers: {'Authorization': 'Bearer configured-session'},
      ),
    )..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return DioMaterialRepository(ApiClient(customDio: dio));
  }

  test('el provider usa el transporte central también para subir', () async {
    final adapter = MaterialHttpAdapter(fixture());
    final dio = Dio(BaseOptions(baseUrl: 'https://central.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final client = ApiClient(customDio: dio);
    final container = ProviderContainer(
      overrides: [apiclientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    final detail = await container
        .read(materialRepositoryProvider)
        .upload(request());
    expect(detail.isSimulatedResponse, isFalse);
    expect(
      adapter.requests.single.uri.toString(),
      'https://central.example.test/api/v1/materials',
    );
    expect(
      container.read(materialListingRepositoryProvider),
      same(container.read(materialRepositoryProvider)),
    );
  });

  test(
    'sube multipart por Gateway con campos, MIME, archivo y headers exactos',
    () async {
      final adapter = MaterialHttpAdapter(fixture());
      final progress = <(int, int)>[];
      await repository(adapter).upload(
        request(),
        onSendProgress: (sent, total) {
          progress.add((sent, total));
        },
      );
      final options = adapter.requests.single;
      expect(options.method, 'POST');
      expect(
        options.uri.toString(),
        'https://gateway.example.test/api/v1/materials',
      );
      expect(options.headers['Authorization'], 'Bearer configured-session');
      expect(options.contentType, startsWith('multipart/form-data; boundary='));
      final form = options.data as FormData;
      expect(Map.fromEntries(form.fields), {
        'title': 'Apuntes de álgebra',
        'description': 'Ejercicios resueltos',
        'year': '2026',
        'type': 'DOCUMENT',
        'subjectId': '44444444-4444-4444-8444-444444444444',
        'careerId': '55555555-5555-4555-8555-555555555555',
        'professorId': '66666666-6666-4666-8666-666666666666',
      });
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'apuntes.pdf');
      expect(form.files.single.value.contentType.toString(), 'application/pdf');
      expect(form.files.single.value.length, file.bytes.length);
      expect(utf8.decode(adapter.body), contains(utf8.decode(file.bytes)));
      expect(progress.last.$1, progress.last.$2);
    },
  );

  test('mapea el DTO público persistido en estado PENDING_REVIEW', () async {
    final detail = await repository(MaterialHttpAdapter(fixture()))
        .upload(request());
    expect(detail.summary.academicYear, 2026);
    expect(detail.summary.reviewStatus, MaterialStatus.pendingReview);
    expect(detail.summary.subject!.id, '44444444-4444-4444-8444-444444444444');
    expect(detail.summary.subject!.name, isNull);
    expect(detail.mimeType, 'application/pdf');
    expect(detail.fileSizeBytes, 26);
    expect(detail.isSimulatedResponse, isFalse);
    expect(detail.toJson()['isSimulatedResponse'], isFalse);
    expect(detail.versions, isEmpty);
    expect(detail.currentVersion, isNull);
    expect(detail.downloadUrl, isEmpty);
  });

  test(
    'conserva true si un entorno antiguo declara respuesta simulada',
    () async {
      final response = fixture()..['isSimulatedResponse'] = true;
      final detail = await repository(MaterialHttpAdapter(response))
          .upload(request());
      expect(detail.isSimulatedResponse, isTrue);
    },
  );

  test(
    'LINK manda externalLink sin archivo, universidad ni nombres de catálogo',
    () async {
      final url = Uri.parse('https://example.test/class');
      final response = fixture();
      (response['data'] as Map<String, dynamic>).addAll({
        'type': 'LINK',
        'fileSize': null,
        'fileUrl': null,
        'mimeType': null,
        'externalLink': url.toString(),
      });
      final adapter = MaterialHttpAdapter(response);
      final detail = await repository(adapter)
          .upload(request(source: ExternalMaterialLink(url), type: 'LINK'));
      final form = adapter.requests.single.data as FormData;
      expect(form.files, isEmpty);
      expect(Map.fromEntries(form.fields)['externalLink'], url.toString());
      expect(form.fields.map((e) => e.key), isNot(contains('universityId')));
      expect(detail.externalLink, url.toString());
      expect(detail.fileSizeBytes, 0);
      expect(detail.mimeType, isNull);
    },
  );

  test(
    'reintentar reconstruye el stream multipart y conserva el archivo',
    () async {
      final adapter = MaterialHttpAdapter(fixture());
      final repo = repository(adapter);
      await repo.upload(request());
      final firstBody = utf8.decode(adapter.body);
      await repo.upload(request());
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[0].data, isNot(same(adapter.requests[1].data)));
      expect(firstBody, contains(utf8.decode(file.bytes)));
      expect(utf8.decode(adapter.body), contains(utf8.decode(file.bytes)));
    },
  );

  for (final code in [400, 401, 404, 413, 415, 502]) {
    test(
      'conserva código, mensaje y cuerpo HTTP $code sin fallback ni reintento',
      () async {
        final body = {'statusCode': code, 'message': 'Error de Material $code'};
        final adapter = MaterialHttpAdapter(body, status: code);
        await expectLater(
          repository(adapter).upload(request()),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', code)
                .having((e) => e.message, 'message', body['message'])
                .having((e) => e.data, 'data', body),
          ),
        );
        expect(adapter.requests, hasLength(1));
        expect(
          adapter.requests.single.uri.origin,
          'https://gateway.example.test',
        );
      },
    );
  }

  test('conserva todos los mensajes de validación de NestJS', () async {
    final adapter = MaterialHttpAdapter({
      'statusCode': 400,
      'message': ['title should not be empty', 'year debe ser válido'],
      'error': 'Bad Request',
    }, status: 400);
    await expectLater(
      repository(adapter).upload(request()),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'title should not be empty\nyear debe ser válido',
        ),
      ),
    );
  });

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('maneja $type sin repetir una creación incierta', () async {
      final adapter = MaterialHttpAdapter(null, failure: type);
      await expectLater(
        repository(adapter).upload(request()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Tiempo de espera'),
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
  }

  test('cancelación explícita no envía el archivo', () async {
    final adapter = MaterialHttpAdapter(fixture());
    final cancel = CancelToken()..cancel();
    await expectLater(
      repository(adapter).upload(request(), cancelToken: cancel),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('cancelada'),
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('errores de respuesta no se convierten en material exitoso', () async {
    for (final response in <Object?>[
      null,
      [],
      {},
      {...fixture(), 'isSimulatedResponse': null},
      {
        ...fixture(),
        'data': {...fixture()['data'], 'year': 2026},
      },
      {
        ...fixture(),
        'data': {...fixture()['data'], 'status': 'PUBLISHED'},
      },
      {
        ...fixture(),
        'data': {...fixture()['data'], 'fileSize': -1},
      },
      {
        ...fixture(),
        'data': {...fixture()['data'], 'subjectId': null},
      },
    ]) {
      await expectLater(
        repository(MaterialHttpAdapter(response)).upload(request()),
        throwsA(isA<ApiException>()),
      );
    }
  });

  test(
    'rechaza combinación archivo/enlace incompatible antes de enviar HTTP',
    () async {
      final adapter = MaterialHttpAdapter(fixture());
      final repo = repository(adapter);
      await expectLater(
        repo.upload(request(type: 'LINK')),
        throwsArgumentError,
      );
      await expectLater(
        repo.upload(
          request(
            source: ExternalMaterialLink(
              Uri.parse('https://example.test/resource'),
            ),
          ),
        ),
        throwsArgumentError,
      );
      expect(adapter.requests, isEmpty);
    },
  );
}
