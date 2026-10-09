import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final materialDetailProvider = FutureProvider.autoDispose
    .family<MaterialDetail, String>((ref, materialId) async {
      final repository = ref.watch(dioMaterialRepositoryProvider);
      return repository.getDetail(materialId);
    });

extension DioErrorCheck on Object? {
  bool get isNotFound {
    final err = this;
    if (err is DioException) {
      return err.response?.statusCode == 404;
    }
    try {
      final dynamic dynErr = err;
      if (dynErr.statusCode == 404) return true;
    } catch (_) {}
    return false;
  }
}
