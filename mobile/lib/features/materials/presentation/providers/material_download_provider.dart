import 'dart:io';

import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadResult {
  final MaterialDownload download;
  final String? savedPath;

  const DownloadResult({required this.download, this.savedPath});
}

class MaterialDownloadNotifier extends Notifier<AsyncValue<DownloadResult?>> {
  @override
  AsyncValue<DownloadResult?> build() => const AsyncData(null);

  Future<DownloadResult?> download(
    String materialId, {
    String? versionId,
  }) async {
    // Si ya hay una descarga en proceso, evita peticiones concurrentes
    if (state.isLoading) return null;

    state = const AsyncLoading();

    try {
      final repository = ref.read(dioMaterialRepositoryProvider);
      final downloadData = await repository.download(
        materialId,
        versionId: versionId,
      );

      String? savedPath;
      try {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/${downloadData.fileName}');
        await file.writeAsBytes(downloadData.bytes, flush: true);
        savedPath = file.path;
      } catch (_) {
        // En plataformas restringidas o pruebas unitarias se preservan los bytes
      }

      final result = DownloadResult(
        download: downloadData,
        savedPath: savedPath,
      );

      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final materialDownloadProvider =
    NotifierProvider<MaterialDownloadNotifier, AsyncValue<DownloadResult?>>(
      MaterialDownloadNotifier.new,
    );
