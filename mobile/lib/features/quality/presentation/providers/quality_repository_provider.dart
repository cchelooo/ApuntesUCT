import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/dio_quality_repository.dart';
import '../../domain/repositories/quality_repository.dart';

/// Provider global de acceso al repositorio de Quality consumido mediante Gateway (Issue #395).
final qualityRepositoryProvider = Provider<QualityRepository>((ref) {
  final apiClient = ref.watch(apiclientProvider);
  return DioQualityRepository(apiClient);
});
