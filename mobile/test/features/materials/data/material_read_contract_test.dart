import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/material_http_adapter.dart';

const materialId = '11111111-1111-4111-8111-111111111111';
const versionId = '22222222-2222-4222-8222-222222222222';
Map<String, dynamic> detail() => jsonDecode(
  File('test/fixtures/materials/gateway_detail.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  DioMaterialRepository repository(MaterialHttpAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return DioMaterialRepository(ApiClient(customDio: dio));
  }

  final file = LocalMaterialFile(
    fileName: 'Guía.pdf',
    mimeType: 'application/pdf',
    bytes: [37, 80, 68, 70],
  );

  test('GET detalle: URI completa y currentVersion pública', () async {
    final adapter = MaterialHttpAdapter(detail(), status: 200);
    final result = await repository(adapter).getDetail(materialId);
    expect(adapter.requests.single.method, 'GET');
    expect(
      adapter.requests.single.uri.toString(),
      'https://gateway.example.test/api/v1/materials/$materialId',
    );
    expect(result.summary.id, materialId);
    expect(result.currentVersion!.id, versionId);
    expect(result.currentVersion!.originalFileName, 'Guía.pdf');
    expect(result.fileSizeBytes, 12345);
    expect(result.currentVersion!.storageKey, isNull);
  });

  for (final field in [
    'id',
    'title',
    'subjectId',
    'materialType',
    'academicYear',
    'status',
    'createdAt',
    'currentVersion',
  ]) {
    test('detalle sin $field rechaza cambio de contrato', () async {
      final data = detail()..remove(field);
      await expectLater(
        repository(MaterialHttpAdapter(data, status: 200))
            .getDetail(materialId),
        throwsA(isA<ApiException>()),
      );
    });
  }
  for (final field in ['id', 'originalFilename', 'fileSize', 'mimeType']) {
    test('versión del detalle sin $field es error visible', () async {
      final data = detail();
      (data['currentVersion'] as Map).remove(field);
      await expectLater(
        repository(MaterialHttpAdapter(data, status: 200))
            .getDetail(materialId),
        throwsA(isA<ApiException>()),
      );
    });
  }

  for (final selection in [null, versionId]) {
    test('descarga binaria y selección de versión $selection', () async {
      final bytes = [0, 255, 128, 37, 80, 68, 70];
      final adapter = MaterialHttpAdapter(
        null,
        status: 200,
        bytes: bytes,
        headers: {
          'content-type': ['application/pdf'],
          'content-disposition': [
            "attachment; filename=Guia.pdf; filename*=UTF-8''Gu%C3%ADa.pdf",
          ],
        },
      );
      final result = await repository(adapter)
          .download(materialId, versionId: selection);
      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.uri.toString(),
        'https://gateway.example.test/api/v1/materials/$materialId/download${selection == null ? '' : '?versionId=$selection'}',
      );
      expect(result.bytes, bytes);
      expect(result.fileName, 'Guía.pdf');
      expect(result.mimeType, 'application/pdf');
    });
  }

  for (final operation in ['detail', 'download', 'version']) {
    for (final status in [401, 403, 404, 413, 415, 502]) {
      test('$operation conserva HTTP $status y mensaje sin fallback', () async {
        final body = {'statusCode': status, 'message': 'Error público $status'};
        final adapter = MaterialHttpAdapter(
          body,
          status: status,
          bytes: operation == 'download' ? utf8.encode(jsonEncode(body)) : null,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
        final repo = repository(adapter);
        final Future<Object> response = switch (operation) {
          'detail' => repo.getDetail(materialId),
          'download' => repo.download(materialId),
          _ => repo.createVersion(materialId, file),
        };
        await expectLater(
          response,
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'HTTP', status)
                .having((e) => e.message, 'mensaje', 'Error público $status')
                .having((e) => e.data, 'cuerpo', body),
          ),
        );
        expect(adapter.requests, hasLength(1));
        expect(adapter.requests.single.uri.host, 'gateway.example.test');
      });
    }
    for (final failure in [
      DioExceptionType.receiveTimeout,
      DioExceptionType.cancel,
    ]) {
      test('$operation comunica $failure', () async {
        final repo = repository(MaterialHttpAdapter(null, failure: failure));
        final Future<Object> response = switch (operation) {
          'detail' => repo.getDetail(materialId),
          'download' => repo.download(materialId),
          _ => repo.createVersion(materialId, file),
        };
        await expectLater(
          response,
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'mensaje',
              contains(
                failure == DioExceptionType.cancel
                    ? 'cancelada'
                    : 'Tiempo de espera',
              ),
            ),
          ),
        );
      });
    }
  }

  test('POST versión: solo file y adaptación del DTO público', () async {
    final adapter = MaterialHttpAdapter({
      'id': versionId,
      'materialId': materialId,
      'versionNumber': 2,
      'originalFilename': 'Guía.pdf',
      'mimeType': 'application/pdf',
      'fileSize': '4',
      'createdBy': 'author',
      'createdAt': '2026-10-22T12:00:00Z',
    });
    final version = await repository(adapter).createVersion(materialId, file);
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(
      req.uri.toString(),
      'https://gateway.example.test/api/v1/materials/$materialId/versions',
    );
    final form = req.data as FormData;
    expect(form.fields, isEmpty);
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'Guía.pdf');
    expect(adapter.body, containsAllInOrder(file.bytes));
    expect(version.fileSizeBytes, 4);
    expect(version.originalFileName, 'Guía.pdf');
  });
  test('LINK no se envía como versión de archivo', () {
    final adapter = MaterialHttpAdapter(null);
    expect(
      () => repository(adapter).createVersion(
        materialId,
        ExternalMaterialLink(Uri.parse('https://example.com')),
      ),
      throwsArgumentError,
    );
    expect(adapter.requests, isEmpty);
  });
}
