import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final materialDownloadProvider = FutureProvider.autoDispose
    .family<MaterialDownload, ({String materialId, String? versionId})>((
      ref,
      params,
    ) async {
      final repository = ref.watch(dioMaterialRepositoryProvider);
      return repository.download(
        params.materialId,
        versionId: params.versionId,
      );
    });
