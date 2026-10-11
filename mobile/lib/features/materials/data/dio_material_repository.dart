import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/material_detail.dart';
import '../domain/models/material_page.dart';
import '../domain/models/material_requests.dart';
import '../domain/models/material_version.dart';
import '../domain/repositories/material_repository.dart';
import 'dio_material_listing_repository.dart';

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
        options: Options(contentType: Headers.multipartFormDataContentType),
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
  Future<MaterialDetail> getDetail(String materialId) async =>
      throw _missingContract('detalle', '#235');

  @override
  Future<MaterialDownload> download(
    String materialId, {
    String? versionId,
  }) async => throw _missingContract('descarga', '#236 y #237');

  @override
  Future<MaterialVersion> createVersion(
    String materialId,
    MaterialSource source,
  ) async => throw _missingContract('versionado', 'INT2');

  ApiException _missingContract(String operation, String dependency) =>
      ApiException(
        message:
            'El contrato de $operation de materiales aún no está disponible '
            '($dependency).',
      );
}
