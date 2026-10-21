import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'material_detail_response.dart';
import 'material_upload_response.dart';

final dioMaterialRepositoryProvider = Provider<MaterialRepository>((ref) {
  final apiClient = ref.watch(apiclientProvider);
  return DioMaterialRepository(apiClient);
});

class DioMaterialRepository implements MaterialRepository {
  final ApiClient _apiClient;

  DioMaterialRepository(this._apiClient);

  @override
  Future<MaterialDetail> getDetail(String materialId) async {
    try {
      final response = await _apiClient.dio.get('/materials/$materialId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : data;
        return materialDetailFromResponse(payload);
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
        '/materials',
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

  /// Subida real vía gateway: POST /materials multipart/form-data (#285).
  ///
  /// Campos según CreateMaterialDto: title, description?, year (YYYY como
  /// texto), type, subjectId, careerId?, professorId?, externalLink? y el
  /// archivo en el campo `file`. Retorna el detalle del 201 en estado
  /// PENDING_REVIEW. Los errores HTTP llegan como [DioException] con el
  /// [ApiException] del interceptor en `error`.
  @override
  Future<MaterialDetail> upload(UploadMaterialRequest request) async {
    try {
      final formData = FormData();
      formData.fields.addAll([
        MapEntry('title', request.title),
        if (request.description != null &&
            request.description!.trim().isNotEmpty)
          MapEntry('description', request.description!.trim()),
        MapEntry('year', request.year.toString()),
        MapEntry('type', request.type),
        MapEntry('subjectId', request.subject.id),
        MapEntry('careerId', request.career.id),
        if (request.professor != null)
          MapEntry('professorId', request.professor!.id),
      ]);

      final source = request.source;
      switch (source) {
        case LocalMaterialFile():
          formData.files.add(
            MapEntry(
              'file',
              MultipartFile.fromBytes(
                source.bytes,
                filename: source.fileName,
                contentType: DioMediaType.parse(source.mimeType),
              ),
            ),
          );
          if (request.backupLink != null) {
            formData.fields.add(
              MapEntry('externalLink', request.backupLink.toString()),
            );
          }
        case ExternalMaterialLink():
          formData.fields.add(
            MapEntry('externalLink', source.url.toString()),
          );
      }

      final response = await _apiClient.dio.post(
        '/materials',
        data: formData,
        options: Options(
          // Sin boundary: Dio lo genera para el multipart.
          contentType: 'multipart/form-data',
          // Subir 15 MB puede superar los 10 s por defecto.
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      final data = response.data;
      final Map<String, dynamic> payload;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        payload = inner is Map<String, dynamic> ? inner : data;
      } else {
        throw const FormatException('Formato de respuesta inválido.');
      }
      return materialDetailFromUploadResponse(payload);
    } on DioException {
      rethrow;
    }
  }

  @override
  Future<MaterialDownload> download(
    String materialId, {
    String? versionId,
  }) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        '/materials/$materialId/download',
        queryParameters: versionId != null ? {'versionId': versionId} : null,
        options: Options(responseType: ResponseType.bytes),
      );

      final contentDisposition =
          response.headers.value('content-disposition') ?? '';
      final contentType =
          response.headers.value('content-type') ?? 'application/octet-stream';

      final filename = _extractFilename(contentDisposition);

      return MaterialDownload(
        bytes: response.data ?? <int>[],
        fileName: filename,
        mimeType: contentType,
      );
    } on DioException {
      rethrow;
    }
  }

  String _extractFilename(String contentDisposition) {
    if (contentDisposition.isEmpty) return 'material_descargado';

    // 1. Manejo prioritario RFC 5987: filename*=UTF-8''Gu%C3%ADa.pdf
    final rfc5987Regex = RegExp(
      r"filename\*=(?:UTF-8|utf-8)''([^;]+)",
      caseSensitive: false,
    );
    final rfcMatch = rfc5987Regex.firstMatch(contentDisposition);
    if (rfcMatch != null) {
      final rawEncoded = rfcMatch.group(1)?.trim() ?? '';
      try {
        return Uri.decodeComponent(rawEncoded);
      } catch (_) {
        return rawEncoded;
      }
    }

    // 2. Fallback estándar: filename="archivo.pdf" o filename=archivo.pdf
    final standardRegex = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    );
    final standardMatch = standardRegex.firstMatch(contentDisposition);
    if (standardMatch != null) {
      return standardMatch.group(1)?.trim() ?? 'material_descargado';
    }

    return 'material_descargado';
  }

  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source,
  ) async {
    throw UnimplementedError();
  }
}
