import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/academic_reference.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/material_http_adapter.dart';

/// Contrato POST publicado en MaterialController/CreateMaterialResponseDto.
/// La respuesta de gateway_create.json es el stub de INT2, no creación real.
void main() {
  Map<String, dynamic> response() => jsonDecode(
    File('test/fixtures/materials/gateway_create.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  UploadMaterialRequest request(
    MaterialSource source, {
    String type = 'DOCUMENT',
  }) => UploadMaterialRequest(
    title: 'Título con tildes: álgebra',
    university: AcademicReference(id: 'university-test'),
    career: AcademicReference(id: 'career-test'),
    subject: AcademicReference(id: 'subject-test'),
    year: 2026,
    type: type,
    source: source,
  );

  DioMaterialRepository repository(MaterialHttpAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    return DioMaterialRepository(ApiClient(customDio: dio));
  }

  // Lee las partes del stream ya serializado, no las estructuras FormData.
  Map<String, ({String headers, List<int> bytes})> wireParts(
    MaterialHttpAdapter adapter,
  ) {
    final contentType = adapter.requests.single.contentType!;
    final boundary = RegExp(r'boundary=([^;]+)')
        .firstMatch(contentType)!
        .group(1)!;
    final result = <String, ({String headers, List<int> bytes})>{};
    for (final segment
        in latin1.decode(adapter.body).split('--$boundary').skip(1)) {
      if (segment.startsWith('--')) break;
      expect(segment, startsWith('\r\n'));
      expect(segment, endsWith('\r\n'));
      final part = segment.substring(2, segment.length - 2);
      final separator = part.indexOf('\r\n\r\n');
      expect(separator, greaterThanOrEqualTo(0));
      final headers = part.substring(0, separator);
      final name = RegExp(r'name="([^"]+)"').firstMatch(headers)!.group(1)!;
      expect(
        result.containsKey(name),
        isFalse,
        reason: 'Campo duplicado: $name',
      );
      result[name] = (
        headers: headers,
        bytes: latin1.encode(part.substring(separator + 4)),
      );
    }
    return result;
  }

  test('el stream conserva exactamente los bytes binarios y campos mínimos del POST', () async {
    final bytes = [...utf8.encode('%PDF-1.7\n'), 0, 255, 128, 13, 10, 127];
    final adapter = MaterialHttpAdapter(response());
    await repository(adapter).upload(
      request(
        LocalMaterialFile(
          fileName: 'apuntes.pdf',
          mimeType: 'application/pdf',
          bytes: bytes,
        ),
      ),
    );
    final options = adapter.requests.single;
    expect(options.method, 'POST');
    expect(
      options.uri.toString(),
      'https://gateway.example.test/api/v1/materials',
    );
    final parts = wireParts(adapter);
    expect(parts.keys.toSet(), {
      'title',
      'year',
      'type',
      'subjectId',
      'careerId',
      'file',
    });
    expect(parts['file']!.headers, contains('filename="apuntes.pdf"'));
    expect(
      parts['file']!.headers.toLowerCase(),
      contains('content-type: application/pdf'),
    );
    expect(parts['file']!.bytes, bytes);
    expect(utf8.decode(parts['title']!.bytes), 'Título con tildes: álgebra');
    expect(utf8.decode(parts['year']!.bytes), '2026');
    expect(utf8.decode(parts['type']!.bytes), 'DOCUMENT');
    expect(utf8.decode(parts['subjectId']!.bytes), 'subject-test');
    expect(utf8.decode(parts['careerId']!.bytes), 'career-test');
  });

  test(
    'el stream LINK conserva la URL completa y no serializa adjuntos ni nulls',
    () async {
      final link = Uri.parse(
        'https://example.test/class?name=%C3%A1lgebra&week=2',
      );
      final data = response();
      (data['data'] as Map<String, dynamic>).addAll({
        'type': 'LINK',
        'fileSize': null,
        'fileUrl': null,
        'mimeType': null,
        'externalLink': link.toString(),
      });
      final adapter = MaterialHttpAdapter(data);
      await repository(adapter)
          .upload(request(ExternalMaterialLink(link), type: 'LINK'));
      final parts = wireParts(adapter);
      expect(parts.keys.toSet(), {
        'title',
        'year',
        'type',
        'subjectId',
        'careerId',
        'externalLink',
      });
      expect(utf8.decode(parts['externalLink']!.bytes), link.toString());
      expect(utf8.decode(parts['type']!.bytes), 'LINK');
    },
  );

  for (final field in [
    'id',
    'title',
    'year',
    'status',
    'type',
    'subjectId',
    'createdAt',
  ]) {
    test(
      'la ausencia del campo contractual $field rechaza la creación',
      () async {
        final data = response();
        (data['data'] as Map<String, dynamic>).remove(field);
        await expectLater(
          repository(MaterialHttpAdapter(data)).upload(
            request(
              LocalMaterialFile(
                fileName: 'apuntes.pdf',
                mimeType: 'application/pdf',
                bytes: [1],
              ),
            ),
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              contains('respuesta de creación inválida'),
            ),
          ),
        );
      },
    );
  }

  test(
    'academicYear no sustituye silenciosamente el campo year de OpenAPI',
    () async {
      final data = response();
      final payload = data['data'] as Map<String, dynamic>;
      payload['academicYear'] = int.parse(payload.remove('year') as String);
      await expectLater(
        repository(MaterialHttpAdapter(data)).upload(
          request(
            LocalMaterialFile(
              fileName: 'apuntes.pdf',
              mimeType: 'application/pdf',
              bytes: [1],
            ),
          ),
        ),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
