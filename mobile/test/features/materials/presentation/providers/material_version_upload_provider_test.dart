import 'dart:async';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_version_upload_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVersionRepository implements MaterialRepository {
  var calls = 0;
  LocalMaterialFile? lastFile;
  Future<MaterialVersion> Function(String materialId, LocalMaterialFile file)?
  onCreate;

  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    calls++;
    final file = source as LocalMaterialFile;
    lastFile = file;
    if (onCreate != null) return onCreate!(materialId, file);
    return MaterialVersion(
      id: 'ver-2',
      materialId: materialId,
      versionNumber: 2,
      originalFileName: file.fileName,
      mimeType: file.mimeType,
      fileSizeBytes: file.bytes.length,
      createdAt: DateTime.utc(2026, 10, 20),
    );
  }

  @override
  Future<MaterialDetail> getDetail(String materialId) =>
      throw UnimplementedError();

  @override
  Future<MaterialPage> list({int page = 1, int pageSize = 10}) =>
      throw UnimplementedError();

  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) =>
      throw UnimplementedError();

  @override
  Future<MaterialDownload> download(String materialId, {String? versionId}) =>
      throw UnimplementedError();
}

LocalMaterialFile _file() => LocalMaterialFile(
  fileName: 'guia-v2.pdf',
  mimeType: 'application/pdf',
  bytes: const [1, 2, 3],
);

void main() {
  group('MaterialVersionUploadNotifier (#292)', () {
    test('éxito crea la versión y retorna true', () async {
      final fake = _FakeVersionRepository();
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(materialVersionUploadProvider('mat-1')).isIdle,
        isTrue,
      );

      final ok = await container
          .read(materialVersionUploadProvider('mat-1').notifier)
          .uploadVersion('mat-1', _file());

      expect(ok, isTrue);
      final state = container.read(materialVersionUploadProvider('mat-1'));
      expect(state.isSuccess, isTrue);
      expect(state.created?.versionNumber, 2);
      expect(fake.calls, 1);
      expect(fake.lastFile?.fileName, 'guia-v2.pdf');
    });

    test('ignora envíos concurrentes (sin duplicar versiones)', () async {
      final fake = _FakeVersionRepository()
        ..onCreate = (_, _) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return MaterialVersion(
            id: 'ver-2',
            materialId: 'mat-1',
            versionNumber: 2,
          );
        };
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        materialVersionUploadProvider('mat-1').notifier,
      );
      final results = await Future.wait([
        notifier.uploadVersion('mat-1', _file()),
        notifier.uploadVersion('mat-1', _file()),
      ]);

      expect(results, [true, false]);
      expect(fake.calls, 1);
    });

    test('ignora envíos concurrentes (sin duplicar versiones)', () async {
      final fake = _FakeVersionRepository()
        ..onCreate = (_, _) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return MaterialVersion(
            id: 'ver-3',
            materialId: 'mat-1',
            versionNumber: 3,
          );
        };
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        materialVersionUploadProvider('mat-1').notifier,
      );
      final results = await Future.wait([
        notifier.uploadVersion('mat-1', _file()),
        notifier.uploadVersion('mat-1', _file()),
      ]);

      expect(results, [true, false]);
      expect(fake.calls, 1);
    });

    test('tabla statusCode → mensaje de error', () async {
      final cases = <({Object error, String contains})>[
        (
          error: ApiException(message: 'Solo el autor.', statusCode: 403),
          contains: 'Solo el autor',
        ),
        (
          error: ApiException(message: 'x', statusCode: 404),
          contains: 'ya no existe',
        ),
        (error: ApiException(message: 'x', statusCode: 413), contains: '15 MB'),
        (
          error: ApiException(message: 'Tipo no admitido.', statusCode: 415),
          contains: 'Formato de archivo no permitido',
        ),
        (
          error: DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.cancel,
          ),
          contains: 'cancelada',
        ),
      ];

      for (final c in cases) {
        final fake = _FakeVersionRepository()
          ..onCreate = (_, _) async => throw c.error;
        final container = ProviderContainer(
          overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final ok = await container
            .read(materialVersionUploadProvider('mat-1').notifier)
            .uploadVersion('mat-1', _file());

        expect(ok, isFalse, reason: 'error: ${c.error}');
        expect(
          container.read(materialVersionUploadProvider('mat-1')).errorMessage,
          contains(c.contains),
          reason: 'error: ${c.error}',
        );
      }
    });

    test('reset vuelve a idle', () async {
      final fake = _FakeVersionRepository()
        ..onCreate = (_, _) async =>
            throw DioException(requestOptions: RequestOptions());
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(materialVersionUploadProvider('mat-1').notifier)
          .uploadVersion('mat-1', _file());
      expect(
        container.read(materialVersionUploadProvider('mat-1')).hasError,
        isTrue,
      );

      container.read(materialVersionUploadProvider('mat-1').notifier).reset();
      expect(
        container.read(materialVersionUploadProvider('mat-1')).isIdle,
        isTrue,
      );
    });

    test('bloquea otra subida global hasta que termina la primera', () async {
      final gate = Completer<MaterialVersion>();
      final fake = _FakeVersionRepository()
        ..onCreate = (materialId, _) {
          if (materialId == 'mat-A') return gate.future;
          return Future.value(
            MaterialVersion(
              id: 'ver-b',
              materialId: materialId,
              versionNumber: 6,
            ),
          );
        };
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final futureA = container
          .read(materialVersionUploadProvider('mat-A').notifier)
          .uploadVersion('mat-A', _file());

      // B se rechaza mientras A sigue en vuelo (una sola subida a la vez).
      final blocked = await container
          .read(materialVersionUploadProvider('mat-B').notifier)
          .uploadVersion('mat-B', _file());
      expect(blocked, isFalse);
      expect(fake.calls, 1);
      expect(
        container.read(materialVersionUploadProvider('mat-B')).isIdle,
        isTrue,
      );

      gate.complete(
        MaterialVersion(id: 'ver-4', materialId: 'mat-A', versionNumber: 4),
      );
      expect(await futureA, isTrue);

      // Tras terminar A, B ya puede subir.
      final okB = await container
          .read(materialVersionUploadProvider('mat-B').notifier)
          .uploadVersion('mat-B', _file());
      expect(okB, isTrue);
      expect(fake.calls, 2);
      expect(
        container
            .read(materialVersionUploadProvider('mat-B'))
            .created
            ?.versionNumber,
        6,
      );
    });

    test('un fallo libera el bloqueo global', () async {
      final fake = _FakeVersionRepository()
        ..onCreate = (_, _) async =>
            throw ApiException(message: 'x', statusCode: 500);
      final container = ProviderContainer(
        overrides: [dioMaterialRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final okA = await container
          .read(materialVersionUploadProvider('mat-A').notifier)
          .uploadVersion('mat-A', _file());
      expect(okA, isFalse);

      final okB = await container
          .read(materialVersionUploadProvider('mat-B').notifier)
          .uploadVersion('mat-B', _file());
      expect(okB, isFalse);
      expect(fake.calls, 2);
    });
  });
}
