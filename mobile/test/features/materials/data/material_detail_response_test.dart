import 'dart:convert';
import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_detail_response.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// MaterialDetailDto de INT2: fileSize es una cadena decimal.
Map<String, dynamic> detail() => {
  'id': '11111111-1111-4111-8111-111111111111',
  'title': 'Guía',
  'description': null,
  'uploaderId': '33333333-3333-4333-8333-333333333333',
  'academicOfferingId': null,
  'universityId': null,
  'careerId': null,
  'subjectId': '44444444-4444-4444-8444-444444444444',
  'professorId': null,
  'materialTypeId': '55555555-5555-4555-8555-555555555555',
  'materialType': 'DOCUMENT',
  'academicYear': 2026,
  'status': 'PUBLISHED',
  'verified': true,
  'externalLink': null,
  'createdAt': '2026-10-14T12:00:00.000Z',
  'updatedAt': '2026-10-14T12:00:00.000Z',
  'currentVersion': {
    'id': '22222222-2222-4222-8222-222222222222',
    'versionNumber': 2,
    'originalFilename': 'Guía.pdf',
    'mimeType': 'application/pdf',
    'fileSize': '12345',
    'createdAt': '2026-10-14T12:00:00.000Z',
  },
};

class DetailAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(
      options.uri.path,
      '/api/v1/materials/11111111-1111-4111-8111-111111111111',
    );
    return ResponseBody.fromString(
      jsonEncode(detail()),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'Repositorio adapta DTO actual y conserva versión descargable',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
        ..httpClientAdapter = DetailAdapter();
      final result = await DioMaterialRepository(ApiClient(customDio: dio))
          .getDetail(detail()['id'] as String);
      expect(result.fileSizeBytes, 12345);
      expect(result.currentVersion, isNotNull);
      expect(result.currentVersion!.materialId, result.summary.id);
      expect(result.currentVersion!.id, '22222222-2222-4222-8222-222222222222');
      expect(result.currentVersion!.originalFileName, 'Guía.pdf');
      expect(result.currentVersion!.versionNumber, 2);
    },
  );
  test('LINK sin archivo conserva currentVersion nula', () {
    final result = materialDetailFromResponse({
      ...detail(),
      'materialType': 'LINK',
      'externalLink': 'https://example.org',
      'currentVersion': null,
    });
    expect(result.currentVersion, isNull);
    expect(result.versions, isEmpty);
    expect(result.fileSizeBytes, 0);
  });
  for (final size in ['-1', '1.5', '1e3', 'abc', 123]) {
    test('Rechaza fileSize inválido $size', () {
      final payload = detail();
      (payload['currentVersion'] as Map)['fileSize'] = size;
      expect(() => materialDetailFromResponse(payload), throwsFormatException);
    });
  }
}
