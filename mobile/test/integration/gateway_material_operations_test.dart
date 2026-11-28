import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/core/session/auth_session.dart';
import 'package:apuntesuct_mobile/core/session/session_controller.dart';
import 'package:apuntesuct_mobile/core/session/session_storage.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_file_handler.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/academic_reference.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_detail_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_download_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_upload_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_version_upload_provider.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/providers/quality_repository_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_session_fixture.dart';
import '../helpers/gateway_contract_fixtures.dart';
import '../helpers/gateway_test_transport.dart';

const materialId = '11111111-1111-4111-8111-111111111111';
const oldVersionId = '22222222-2222-4222-8222-222222222222';
const newVersionId = '77777777-7777-4777-8777-777777777777';
final fileBytes = utf8.encode('%PDF-1.4\n%%EOF\n');
LocalMaterialFile file() => LocalMaterialFile(
  fileName: 'Guía.pdf',
  mimeType: 'application/pdf',
  bytes: fileBytes,
);

UploadMaterialRequest uploadRequest() => UploadMaterialRequest(
  title: 'Guía de redes',
  description: 'Ejercicios',
  year: 2026,
  type: 'DOCUMENT',
  university: AcademicReference(id: universityId),
  career: AcademicReference(id: careerId),
  subject: AcademicReference(id: subjectId),
  professor: AcademicReference(id: professorId),
  source: file(),
);

Map<String, dynamic> createdResponse() => {
  'status': 'success',
  'isSimulatedResponse': false,
  'message': 'Material registrado en revisión',
  'data': {
    'id': materialId,
    'title': 'Guía de redes',
    'description': 'Ejercicios',
    'year': '2026',
    'type': 'DOCUMENT',
    'status': 'PENDING_REVIEW',
    'subjectId': subjectId,
    'careerId': careerId,
    'professorId': professorId,
    'universityId': universityId,
    'fileUrl': null,
    'fileSize': fileBytes.length,
    'mimeType': 'application/pdf',
    'externalLink': null,
    'createdAt': timestamp,
  },
};

class MemoryFiles implements MaterialFileHandler {
  final saved = <MaterialDownload>[];
  @override
  Future<String> save(MaterialDownload download) async {
    saved.add(download);
    return '/test-cache/${download.fileName}';
  }

  @override
  Future<void> open(String path, String mimeType) async =>
      fail('La suite no abre visores nativos.');
}

void expectFilePart(RequestOptions request, GatewayTestTransport transport) {
  expect(request.contentType, startsWith('multipart/form-data; boundary='));
  final form = request.data as FormData;
  expect(form.files, hasLength(1));
  expect(form.files.single.key, 'file');
  expect(form.files.single.value.filename, 'Guía.pdf');
  expect(form.files.single.value.length, fileBytes.length);
  expect(form.files.single.value.contentType.toString(), 'application/pdf');
  expect(utf8.decode(transport.bodies.last), contains(utf8.decode(fileBytes)));
}

void main() {
  test('sesión compartida en subida, versionado y moderación rechazada', () async {
    final now = DateTime.utc(2026, 11, 23);
    var clock = now;
    final storage = MemorySessionStorage();
    final controller = SessionController(storage, now: () => clock);
    final session = AuthSession.fromLogin(loginFixture(now: now), now);
    expect(await controller.accept(session, controller.beginLogin()), isTrue);

    var uploadStatus = 201;
    var simulateUpload = false;
    final transport = GatewayTestTransport(
      (request) {
        switch (request.uri.path) {
          case '/api/v1/materials':
            expect(request.method, 'POST');
            expect(
              (request.data as FormData).fields.map((f) => f.key),
              isNot(contains('uploaderId')),
            );
            return gatewayJson(
              uploadStatus == 201
                  ? (createdResponse()
                      ..['isSimulatedResponse'] = simulateUpload)
                  : {'message': 'Permiso denegado'},
              status: uploadStatus,
            );
          case '/api/v1/materials/$materialId/versions':
            expect(request.method, 'POST');
            expect((request.data as FormData).fields, isEmpty);
            return gatewayJson({'message': 'Solo el autor.'}, status: 403);
          case '/api/v1/quality/moderation/materials':
            expect(
              request.uri.toString(),
              '$testGatewayUrl/quality/moderation/materials?page=1&pageSize=20',
            );
            final signedIn = request.headers['Authorization'] != null;
            return gatewayJson({
              'message': signedIn ? 'Rol insuficiente' : 'Sesión requerida',
            }, status: signedIn ? 403 : 401);
          default:
            fail('Ruta inesperada: ${request.uri}');
        }
      },
      allowedMethods: {'GET', 'POST'},
      checkAuthorization: (request) {
        expect(
          request.headers['Authorization'],
          clock == now ? 'Bearer ${session.accessToken}' : isNull,
        );
      },
    );
    final dio = Dio(BaseOptions(baseUrl: testGatewayUrl))
      ..httpClientAdapter = transport;
    final container = ProviderContainer(
      overrides: [
        apiclientProvider.overrideWithValue(
          ApiClient(customDio: dio, session: controller),
        ),
        sessionControllerProvider.overrideWithValue(controller),
      ],
    );
    addTearDown(() {
      container.dispose();
      dio.close(force: true);
      controller.dispose();
    });

    final upload = container.read(materialUploadProvider.notifier);
    expect(await upload.upload(uploadRequest()), isTrue);
    expect(
      container.read(materialUploadProvider).created!.summary.status,
      'PENDING_REVIEW',
    );
    simulateUpload = true;
    expect(await upload.upload(uploadRequest()), isFalse);
    expect(container.read(materialUploadProvider).created, isNull);
    expect(
      container.read(materialUploadProvider).errorMessage,
      contains('simuló'),
    );
    uploadStatus = 403;
    expect(await upload.upload(uploadRequest()), isFalse);
    expect(
      container.read(materialUploadProvider).errorMessage,
      contains('no tiene permiso'),
    );

    final version = materialVersionUploadProvider(materialId);
    expect(
      await container.read(version.notifier).uploadVersion(materialId, file()),
      isFalse,
    );
    expect(container.read(version).created, isNull);
    expect(container.read(version).errorMessage, 'Solo el autor.');
    expect(container.read(materialVersionUploadLockProvider), isNull);

    final quality = container.read(qualityRepositoryProvider);
    await expectLater(
      quality.listModerationMaterials(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'HTTP', 403)),
    );
    expect(controller.current, same(session));
    expect(await storage.read(), isNotNull);

    clock = session.expiresAt;
    await expectLater(
      quality.listModerationMaterials(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'HTTP', 401)),
    );
    expect(controller.current, isNull);
    expect(controller.needsSignIn, isTrue);
    expect(await storage.read(), isNull);
    expect(container.read(materialUploadProvider).isIdle, isTrue);
    expect(container.read(version).isIdle, isTrue);
  });

  test(
    'subida multipart real llega al provider sin doble envío y conserva el 201',
    () async {
      final gate = Completer<void>();
      late GatewayTestTransport transport;
      transport = GatewayTestTransport((request) async {
        expect(request.uri.toString(), '$testGatewayUrl/materials');
        expectFilePart(request, transport);
        expect(Map.fromEntries((request.data as FormData).fields), {
          'title': 'Guía de redes',
          'description': 'Ejercicios',
          'year': '2026',
          'type': 'DOCUMENT',
          'subjectId': subjectId,
          'careerId': careerId,
          'professorId': professorId,
        });
        await gate.future;
        return gatewayJson(createdResponse(), status: 201);
      }, allowedMethods: {'POST'});
      final container = gatewayTestContainer(transport);
      final notifier = container.read(materialUploadProvider.notifier);
      final first = notifier.upload(uploadRequest());
      expect(container.read(materialUploadProvider).isUploading, isTrue);
      expect(await notifier.upload(uploadRequest()), isFalse);
      gate.complete();
      expect(await first, isTrue);
      final created = container.read(materialUploadProvider).created!;
      expect(created.summary.id, materialId);
      expect(created.summary.reviewStatus.code, 'PENDING_REVIEW');
      expect(created.summary.subject!.id, subjectId);
      expect(created.fileSizeBytes, fileBytes.length);
      expect(transport.requests, hasLength(1));
    },
  );

  for (final (status, message) in [
    (413, '15 MB'),
    (415, 'Formato de archivo'),
    (401, 'iniciar sesión'),
    (500, 'No se pudo registrar el archivo'),
  ]) {
    test(
      'subida HTTP $status conserva un mensaje utilizable y no crea material',
      () async {
        final transport = GatewayTestTransport((request) {
          expect(request.uri.toString(), '$testGatewayUrl/materials');
          return gatewayJson({
            'statusCode': status,
            'message': 'No se pudo registrar el archivo',
          }, status: status);
        }, allowedMethods: {'POST'});
        final container = gatewayTestContainer(transport);
        expect(
          await container
              .read(materialUploadProvider.notifier)
              .upload(uploadRequest()),
          isFalse,
        );
        final state = container.read(materialUploadProvider);
        expect(state.created, isNull);
        expect(state.isUploading, isFalse);
        expect(state.errorMessage, contains(message));
        expect(transport.requests, hasLength(1));
      },
    );
  }

  test('timeout de subida admite reintento con un multipart nuevo', () async {
    var calls = 0;
    final forms = <FormData>[];
    final transport = GatewayTestTransport((request) {
      expect(request.uri.toString(), '$testGatewayUrl/materials');
      forms.add(request.data as FormData);
      if (++calls == 1) {
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.sendTimeout,
        );
      }
      return gatewayJson(createdResponse(), status: 201);
    }, allowedMethods: {'POST'});
    final container = gatewayTestContainer(transport);
    final notifier = container.read(materialUploadProvider.notifier);
    expect(await notifier.upload(uploadRequest()), isFalse);
    expect(
      container.read(materialUploadProvider).errorMessage,
      contains('Tiempo de espera'),
    );
    expect(await notifier.upload(uploadRequest()), isTrue);
    expect(identical(forms.first, forms.last), isFalse);
    expect(transport.bodies.every((body) => body.isNotEmpty), isTrue);
  });

  test('versionado actualiza ambos providers y descarga la versión histórica por Gateway', () async {
    var current = 2;
    final detail = jsonDecode(
      File('test/fixtures/materials/gateway_detail.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final createdVersion = {
      'id': newVersionId,
      'materialId': materialId,
      'versionNumber': 3,
      'originalFilename': 'Guía.pdf',
      'mimeType': 'application/pdf',
      'fileSize': fileBytes.length.toString(),
      'createdAt': timestamp,
    };
    late GatewayTestTransport transport;
    transport = GatewayTestTransport((request) {
      if (request.method == 'POST') {
        expect(
          request.uri.toString(),
          '$testGatewayUrl/materials/$materialId/versions',
        );
        expectFilePart(request, transport);
        expect((request.data as FormData).fields, isEmpty);
        current = 3;
        return gatewayJson(createdVersion, status: 201);
      }
      if (request.path.endsWith('/download')) {
        expect(
          request.uri.toString(),
          '$testGatewayUrl/materials/$materialId/download?versionId=$oldVersionId',
        );
        return ResponseBody.fromBytes(
          fileBytes,
          200,
          headers: {
            'content-type': ['application/pdf'],
            'content-disposition': [
              "attachment; filename*=UTF-8''Gu%C3%ADa.pdf",
            ],
          },
        );
      }
      expect(request.uri.toString(), '$testGatewayUrl/materials/$materialId');
      return gatewayJson({
        ...detail,
        'currentVersion': current == 2
            ? detail['currentVersion']
            : createdVersion,
        'versions': [
          if (current == 3) createdVersion,
          detail['currentVersion'],
        ],
      });
    }, allowedMethods: {'GET', 'POST'});
    final files = MemoryFiles();
    final container = gatewayTestContainer(
      transport,
      overrides: [materialFileHandlerProvider.overrideWithValue(files)],
    );
    final direct = materialDetailProvider(materialId);
    final route = materialDetailByIdProvider(materialId);
    final directSub = container.listen(direct, (_, _) {});
    final routeSub = container.listen(route, (_, _) {});
    addTearDown(directSub.close);
    addTearDown(routeSub.close);
    expect(
      (await container.read(direct.future)).currentVersion!.versionNumber,
      2,
    );
    expect(
      (await container.read(route.future)).currentVersion!.versionNumber,
      2,
    );
    expect(
      await container
          .read(materialVersionUploadProvider(materialId).notifier)
          .uploadVersion(materialId, file()),
      isTrue,
    );
    expect(
      (await container.read(direct.future)).currentVersion!.versionNumber,
      3,
    );
    final updated = await container.read(route.future);
    expect(updated.currentVersion!.id, newVersionId);
    expect(updated.versions.map((v) => v.versionNumber), [3, 2]);
    final result = await container
        .read(materialDownloadProvider.notifier)
        .download(materialId, versionId: oldVersionId);
    expect(result!.download.bytes, fileBytes);
    expect(result.download.fileName, 'Guía.pdf');
    expect(result.download.mimeType, 'application/pdf');
    expect(result.versionId, oldVersionId);
    expect(files.saved.single, same(result.download));
    expect(container.read(materialDownloadProvider).requireValue, same(result));
    expect(transport.requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(transport.requests, hasLength(6));
  });

  for (final status in [404, 502]) {
    test(
      'descarga fallida HTTP $status no guarda bytes ni devuelve éxito',
      () async {
        final transport = GatewayTestTransport((request) {
          expect(
            request.uri.toString(),
            '$testGatewayUrl/materials/$materialId/download',
          );
          return gatewayJson({
            'statusCode': status,
            'message': 'Descarga no disponible',
          }, status: status);
        });
        final files = MemoryFiles();
        final container = gatewayTestContainer(
          transport,
          overrides: [materialFileHandlerProvider.overrideWithValue(files)],
        );
        await expectLater(
          container
              .read(materialDownloadProvider.notifier)
              .download(materialId),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'HTTP', status)
                .having((e) => e.message, 'mensaje', 'Descarga no disponible'),
          ),
        );
        expect(container.read(materialDownloadProvider).hasError, isTrue);
        expect(files.saved, isEmpty);
      },
    );
  }
}
