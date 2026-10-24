import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/academic_reference.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_upload_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../upload_catalog_harness.dart' show testBdId, testIciId, testUctId;

class _FakeMaterialRepository implements MaterialRepository {
  UploadMaterialRequest? lastRequest;
  Future<MaterialDetail> Function(UploadMaterialRequest request)? onUpload;

  MaterialDetail get canned => MaterialDetail(
    summary: const MaterialSummary(id: 'mat-900', title: 'Guía de prueba'),
    fileSizeBytes: 3,
  );

  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) {
    lastRequest = request;
    if (onUpload != null) return onUpload!(request);
    return Future.value(canned);
  }

  @override
  Future<MaterialDetail> getDetail(String materialId) =>
      throw UnimplementedError();

  @override
  Future<MaterialPage> list({int page = 1, int pageSize = 10}) =>
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

UploadMaterialRequest _request() => UploadMaterialRequest(
  title: 'Guía de prueba',
  university: AcademicReference(id: testUctId),
  career: AcademicReference(id: testIciId),
  subject: AcademicReference(id: testBdId),
  year: 2026,
  type: 'DOCUMENT',
  source: LocalMaterialFile(
    fileName: 'apuntes.pdf',
    mimeType: 'application/pdf',
    bytes: const [1, 2, 3],
  ),
);

void main() {
  group('MaterialUploadNotifier (#285)', () {
    test('éxito deja el detalle creado y retorna true', () async {
      final fake = _FakeMaterialRepository();
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(materialUploadProvider).isIdle, isTrue);

      final ok = await container
          .read(materialUploadProvider.notifier)
          .upload(_request());

      expect(ok, isTrue);
      final state = container.read(materialUploadProvider);
      expect(state.isSuccess, isTrue);
      expect(state.created?.summary.title, 'Guía de prueba');
      expect(fake.lastRequest?.title, 'Guía de prueba');
    });

    test('413 mapea a mensaje de límite de 15 MB y retorna false', () async {
      final fake = _FakeMaterialRepository()
        ..onUpload = (_) async => throw DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.badResponse,
          error: ApiException(
            message: 'El archivo excede el tamaño máximo.',
            statusCode: 413,
          ),
        );
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(materialUploadProvider.notifier)
          .upload(_request());

      expect(ok, isFalse);
      final state = container.read(materialUploadProvider);
      expect(state.hasError, isTrue);
      expect(state.errorMessage, contains('15 MB'));
      expect(state.created, isNull);
    });

    test('tabla statusCode → mensaje de error (H7)', () async {
      final cases = <({Object error, String contains})>[
        (
          error: ApiException(message: 'subjectId inválido.', statusCode: 400),
          contains: 'subjectId inválido.',
        ),
        (error: ApiException(message: 'x', statusCode: 401), contains: 'autor'),
        (
          error: ApiException(message: 'x', statusCode: 415),
          contains: 'Formato',
        ),
        (
          error: ApiException(message: 'x', statusCode: 502),
          contains: 'no está disponible',
        ),
        (
          // Sin ApiException (timeout/red): mensaje genérico de red.
          error: DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.connectionTimeout,
          ),
          contains: 'No fue posible subir',
        ),
      ];

      for (final c in cases) {
        final fake = _FakeMaterialRepository()
          ..onUpload = (_) async => throw c.error;
        final container = ProviderContainer(
          overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final ok = await container
            .read(materialUploadProvider.notifier)
            .upload(_request());

        expect(ok, isFalse, reason: 'error: ${c.error}');
        expect(
          container.read(materialUploadProvider).errorMessage,
          contains(c.contains),
          reason: 'error: ${c.error}',
        );
      }
    });

    test('reset vuelve a idle tras éxito o error', () async {
      final fake = _FakeMaterialRepository()
        ..onUpload = (_) async =>
            throw DioException(requestOptions: RequestOptions());
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container.read(materialUploadProvider.notifier).upload(_request());
      expect(container.read(materialUploadProvider).hasError, isTrue);

      container.read(materialUploadProvider.notifier).reset();
      expect(container.read(materialUploadProvider).isIdle, isTrue);
    });
  });
}
