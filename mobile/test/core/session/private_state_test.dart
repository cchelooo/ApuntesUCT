import 'dart:async';

import 'package:apuntesuct_mobile/core/session/session_controller.dart';
import 'package:apuntesuct_mobile/core/session/session_storage.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/academic_reference.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_fixtures.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_upload_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingUpload implements MaterialRepository {
  final completed = Completer<MaterialDetail>();
  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) =>
      completed.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('logout clears pending upload and its late success cannot refill private state', () async {
    final repository = _PendingUpload();
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
        dioMaterialRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(materialUploadProvider.notifier);
    final request = UploadMaterialRequest(
      title: 'Privado',
      university: AcademicReference(id: 'u', name: 'U'),
      career: AcademicReference(id: 'c', name: 'C'),
      subject: AcademicReference(id: 's', name: 'S'),
      year: 2026,
      type: 'DOCUMENT',
      source: LocalMaterialFile(
        fileName: 'test.pdf',
        mimeType: 'application/pdf',
        bytes: [1],
      ),
    );
    final pending = notifier.upload(request);
    expect(container.read(materialUploadProvider).isUploading, isTrue);
    await container.read(sessionControllerProvider).clear();
    expect(container.read(materialUploadProvider).isIdle, isTrue);
    repository.completed.complete(MaterialFixtures.detailForId('mat-101')!);
    expect(await pending, isFalse);
    expect(container.read(materialUploadProvider).isIdle, isTrue);
    expect(container.read(materialUploadProvider).created, isNull);
  });
}
