import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/material_detail.dart';
import '../domain/models/material_page.dart';
import '../domain/models/material_requests.dart';
import '../domain/models/material_version.dart';
import '../domain/repositories/material_repository.dart';
import 'dio_material_listing_repository.dart';
import 'material_detail_response.dart';

final dioMaterialRepositoryProvider = Provider<MaterialRepository>((ref) {
  return DioMaterialRepository(ref.watch(apiclientProvider));
});

/// Adaptador del contrato publicado por INT2. No consulta URLs de archivos.
class DioMaterialRepository implements MaterialRepository {
  DioMaterialRepository(this._apiClient)
    : _listing = DioMaterialListingRepository(_apiClient);

  final ApiClient _apiClient;
  final DioMaterialListingRepository _listing;

  @override
  Future<MaterialPage> list({int page = 1, int pageSize = 10}) =>
      _listing.list(page: page, pageSize: pageSize);

  @override
  Future<MaterialDetail> upload(
    UploadMaterialRequest request, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    // FormData nuevo por intento: Dio consume/finaliza el stream multipart.
    final fields = <String, dynamic>{
      'title': request.title,
      if (request.description != null) 'description': request.description,
      'year': request.year.toString(),
      'type': request.type,
      'subjectId': request.subject.id,
      'careerId': request.career.id,
      if (request.professor != null) 'professorId': request.professor!.id,
    };
    // universityId es derivado por Backend; OpenAPI no lo acepta en el body.
    switch (request.source) {
      case LocalMaterialFile(:final fileName, :final mimeType, :final bytes):
        if (request.type == 'LINK') {
          throw ArgumentError('LINK requiere un enlace y no admite archivo.');
        }
        fields['file'] = MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        );
        // Enlace de respaldo opcional junto al archivo (#285: el backend lo
        // acepta y el formulario lo ofrece).
        if (request.backupLink != null) {
          fields['externalLink'] = request.backupLink.toString();
        }
      case ExternalMaterialLink(:final url):
        if (request.type != 'LINK') {
          throw ArgumentError(
            'Este tipo de material requiere un archivo local.',
          );
        }
        fields['externalLink'] = url.toString();
    }

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/materials',
        data: FormData.fromMap(fields),
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          // Subir 15 MB puede superar los 10 s por defecto; el 201 también
          // puede tardar en red lenta (H8).
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 30),
        ),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      return _createdMaterial(response.data);
    } on DioException catch (error) {
      final intercepted = error.error;
      if (intercepted is ApiException) throw intercepted;
      throw ApiException.fromDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        message: 'El servidor devolvió una respuesta de creación inválida.',
        data: error,
      );
    }
  }

  MaterialDetail _createdMaterial(Object? response) {
    if (response is! Map<String, dynamic> ||
        response['status'] != 'success' ||
        response['isSimulatedResponse'] is! bool ||
        response['data'] is! Map<String, dynamic>) {
      throw const FormatException('No coincide con CreateMaterialResponseDto.');
    }
    final data = response['data'] as Map<String, dynamic>;
    final year = data['year'];
    if (year is! String || !RegExp(r'^(19|20)\d{2}$').hasMatch(year)) {
      throw const FormatException('year debe ser un año de cuatro dígitos.');
    }
    if (data['status'] != 'PENDING_REVIEW' ||
        data['type'] is! String ||
        !const {
          'DOCUMENT',
          'PRESENTATION',
          'LINK',
          'EXAM',
          'SUMMARY',
        }.contains(data['type'])) {
      throw const FormatException('Estado o tipo de creación inválido.');
    }
    final detail = MaterialDetail.fromJson({
      ...data,
      'year': int.parse(year),
      'fileSizeBytes': data['fileSize'] ?? 0,
      'isSimulatedResponse': response['isSimulatedResponse'],
      // fileUrl del POST no autoriza acceso directo a almacenamiento externo.
      'downloadUrl': '',
    });
    if (detail.summary.subject == null || detail.summary.createdAt == null) {
      throw const FormatException('Faltan metadatos obligatorios de creación.');
    }
    return detail;
  }

  @override
  Future<MaterialDetail> getDetail(
    String materialId, {
    CancelToken? cancelToken,
  }) => _guard('detalle', () async {
    final response = await _apiClient.dio.get<dynamic>(
      '/materials/${Uri.encodeComponent(materialId)}',
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('El detalle debe ser un objeto.');
    }
    final payload = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
    for (final key in [
      'id',
      'title',
      'subjectId',
      'materialType',
      'academicYear',
      'status',
      'createdAt',
      'currentVersion',
    ]) {
      if (!payload.containsKey(key) ||
          (key != 'currentVersion' && payload[key] == null)) {
        throw FormatException('Falta $key en MaterialDetailDto.');
      }
    }
    return materialDetailFromResponse(payload);
  });

  @override
  Future<MaterialDownload> download(
    String materialId, {
    String? versionId,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) => _guard('descarga', () async {
    final response = await _apiClient.dio.get<List<int>>(
      '/materials/${Uri.encodeComponent(materialId)}/download',
      queryParameters: versionId == null ? null : {'versionId': versionId},
      options: Options(responseType: ResponseType.bytes),
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return MaterialDownload(
      bytes: response.data ?? <int>[],
      fileName: _extractFilename(
        response.headers.value('content-disposition') ?? '',
      ),
      mimeType:
          response.headers.value('content-type') ?? 'application/octet-stream',
    );
  });

  String _extractFilename(String disposition) {
    final extended = RegExp(
      r"filename\*=(?:UTF-8)''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);
    if (extended != null) {
      try {
        return Uri.decodeComponent(extended.group(1)!.trim());
      } on ArgumentError {
        // Un encabezado mal codificado todavía puede tener filename estándar.
      }
    }
    return RegExp(
          r'filename="?([^";]+)"?',
          caseSensitive: false,
        ).firstMatch(disposition)?.group(1)?.trim() ??
        'material_descargado';
  }

  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) {
    if (source is! LocalMaterialFile) {
      throw ArgumentError('Una nueva versión requiere un archivo local.');
    }
    return _guard('versionado', () async {
      final response = await _apiClient.dio.post<dynamic>(
        '/materials/${Uri.encodeComponent(materialId)}/versions',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            source.bytes,
            filename: source.fileName,
            contentType: DioMediaType.parse(source.mimeType),
          ),
        }),
        options: Options(contentType: Headers.multipartFormDataContentType),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['materialId'] != materialId) {
        throw const FormatException('Versión ausente o de otro material.');
      }
      final size = data['fileSize'];
      if (size is! String ||
          !RegExp(r'^(0|[1-9]\d*)$').hasMatch(size) ||
          int.tryParse(size) == null ||
          data['originalFilename'] is! String ||
          data['mimeType'] is! String ||
          data['createdAt'] == null) {
        throw const FormatException('Metadatos de versión inválidos.');
      }
      return MaterialVersion.fromJson({
        ...data,
        'originalFileName': data['originalFilename'],
        'fileSizeBytes': int.parse(size),
      });
    });
  }

  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      final response = error.response;
      if (response != null && response.data is List<int>) {
        try {
          final decoded = jsonDecode(utf8.decode(response.data as List<int>));
          throw ApiException.fromDioException(
            error.copyWith(
              response: Response(
                requestOptions: error.requestOptions,
                statusCode: response.statusCode,
                data: decoded,
                headers: response.headers,
              ),
            ),
          );
        } on FormatException {
          // Un error no JSON conserva al menos su código HTTP.
        }
      }
      final intercepted = error.error;
      if (intercepted is ApiException) throw intercepted;
      throw ApiException.fromDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        message: 'El servidor devolvió una respuesta de $operation inválida.',
        data: error,
      );
    }
  }
}
