import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
// import '../../../materials/data/material_file_handler.dart';
import '../../../materials/domain/models/material_requests.dart';
import '../../../materials/presentation/providers/material_download_provider.dart';
import '../../domain/models/moderation_material_detail.dart';
import 'moderation_queue_provider.dart';

/// Detalle privado de un material pendiente de moderación (#410).
final moderationMaterialDetailProvider = FutureProvider.autoDispose
    .family<ModerationMaterialDetail, String>((ref, materialId) async {
      if (!ref.watch(canAccessModerationProvider)) {
        throw ApiException(
          statusCode: 403,
          message:
              'No tienes permisos de moderación para revisar este material.',
        );
      }
      return ref
          .read(qualityModerationRepositoryProvider)
          .getPendingMaterialDetail(materialId);
    });

/// Resultado de descarga autorizada de un archivo pendiente en moderación.
class ModerationDownloadResult {
  final String materialId;
  final String? versionId;
  final MaterialDownload download;
  final String savedPath;

  const ModerationDownloadResult({
    required this.materialId,
    this.versionId,
    required this.download,
    required this.savedPath,
  });
}

/// Controla la descarga privada y apertura nativa de materiales pendientes (#410).
class ModerationMaterialDownloadNotifier
    extends Notifier<AsyncValue<ModerationDownloadResult?>> {
  @override
  AsyncValue<ModerationDownloadResult?> build() => const AsyncData(null);

  Future<ModerationDownloadResult?> download(
    String materialId, {
    String? versionId,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();

    try {
      final downloadData = await ref
          .read(qualityModerationRepositoryProvider)
          .downloadPendingMaterial(materialId, versionId: versionId);

      final savedPath = await ref
          .read(materialFileHandlerProvider)
          .save(downloadData);

      final result = ModerationDownloadResult(
        materialId: materialId,
        versionId: versionId,
        download: downloadData,
        savedPath: savedPath,
      );

      if (ref.mounted) state = AsyncData(result);
      return result;
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> openSavedFile(ModerationDownloadResult result) {
    return ref
        .read(materialFileHandlerProvider)
        .open(result.savedPath, result.download.mimeType);
  }
}

final moderationMaterialDownloadProvider =
    NotifierProvider.autoDispose<
      ModerationMaterialDownloadNotifier,
      AsyncValue<ModerationDownloadResult?>
    >(ModerationMaterialDownloadNotifier.new);

/// Mecanismo inyectable para abrir enlaces externos validados (`http`/`https`).
typedef ModerationExternalLinkOpener = Future<void> Function(Uri uri);

final moderationExternalLinkOpenerProvider =
    Provider<ModerationExternalLinkOpener>(
      (_) =>
          (uri) => Clipboard.setData(ClipboardData(text: uri.toString())),
    );
