import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_file_handler.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadResult {
  final String materialId;
  final String? versionId;
  final MaterialDownload download;
  final String savedPath;

  const DownloadResult({
    required this.materialId,
    this.versionId,
    required this.download,
    required this.savedPath,
  });
}

final materialFileHandlerProvider = Provider<MaterialFileHandler>(
  (_) => NativeMaterialFileHandler(),
);

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

      final savedPath = await ref
          .read(materialFileHandlerProvider)
          .save(downloadData);

      final result = DownloadResult(
        materialId: materialId,
        versionId: versionId,
        download: downloadData,
        savedPath: savedPath,
      );

      if (ref.mounted) state = AsyncData(result);
      return result;
    } catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
      rethrow;
    }
  }
}

final materialDownloadProvider =
    NotifierProvider<MaterialDownloadNotifier, AsyncValue<DownloadResult?>>(
      MaterialDownloadNotifier.new,
    );
