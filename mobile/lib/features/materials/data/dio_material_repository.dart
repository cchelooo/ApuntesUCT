import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final materialApiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final dioMaterialRepositoryProvider = Provider<MaterialRepository>((ref) {
  final apiClient = ref.watch(materialApiClientProvider);
  return DioMaterialRepository(apiClient);
});

class DioMaterialRepository implements MaterialRepository {
  final ApiClient _apiClient;

  DioMaterialRepository(this._apiClient);

  @override
  Future<MaterialDetail> getDetail(String materialId) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/v1/materials/$materialId',
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : data;
        return MaterialDetail.fromJson(payload);
      }
      throw const FormatException('Formato de respuesta inválido.');
    } on DioException {
      rethrow;
    }
  }

  @override
  Future<MaterialPage> list({int page = 1, int pageSize = 10}) async {
    try {
      final response = await _apiClient.dio.get(
        '/api/v1/materials',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return MaterialPage.fromJson(data);
      }
      return MaterialPage(
        items: const [],
        page: page,
        pageSize: pageSize,
        total: 0,
      );
    } on DioException {
      rethrow;
    }
  }

  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) async {
    throw UnimplementedError();
  }

  @override
  Future<MaterialDownload> download(
    String materialId, {
    String? versionId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (versionId != null && versionId.isNotEmpty) {
        queryParams['versionId'] = versionId;
      }

      final response = await _apiClient.dio.get<List<int>>(
        '/api/v1/materials/$materialId/download',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': '*/*'},
        ),
      );

      // Extracción del nombre de archivo desde Content-Disposition
      String fileName = 'material_$materialId';
      final disposition = response.headers.value('content-disposition');
      if (disposition != null) {
        final match = RegExp(r'''filename[^;=\n]*=((['"]).*?\2|[^;\n]*)''')
            .firstMatch(disposition);
        if (match != null && match.group(1) != null) {
          fileName = match
              .group(1)!
              .replaceAll('"', '')
              .replaceAll("'", '')
              .trim();
        }
      }

      final mimeType =
          response.headers.value('content-type') ?? 'application/octet-stream';
      final bytes = response.data ?? <int>[];

      return MaterialDownload(
        fileName: fileName,
        mimeType: mimeType,
        bytes: bytes,
      );
    } on DioException {
      rethrow;
    }
  }

  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source,
  ) async {
    throw UnimplementedError();
  }
}
