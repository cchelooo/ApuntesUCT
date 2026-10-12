import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/dio_material_listing_repository.dart';
import '../../domain/models/material_page.dart';
import '../../domain/repositories/material_listing_repository.dart';

final materialApiClientProvider = Provider<ApiClient>((ref) {
  return ref.watch(apiclientProvider);
});

/// Sustituible por un fake sin crear Dio ni consultar el Backend.
final materialListingRepositoryProvider = Provider<MaterialListingRepository>((
  ref,
) {
  return DioMaterialListingRepository(ref.watch(materialApiClientProvider));
});

/// Página del listado básico; búsqueda y filtros continúan en Search.
final materialListProvider = FutureProvider.autoDispose
    .family<MaterialPage, int>((ref, page) {
      return ref.watch(materialListingRepositoryProvider).list(page: page);
    });
