import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/material_page.dart';
import '../domain/models/material_requests.dart';
import '../domain/repositories/search_repository.dart';

/// Permite distinguir una integración pendiente de una búsqueda sin resultados.
class SearchContractPendingException extends ApiException {
  SearchContractPendingException({required super.message, super.data});
}

/// Adaptador preparatorio del único contrato publicado: GET /search?q=...
/// No supone nombres de filtros, orden, paginación ni DTOs de resultados.
class DioSearchRepository implements SearchRepository {
  DioSearchRepository(this._client);
  final ApiClient _client;

  static const stubMessage =
      'Search Service inicializado correctamente. '
      'Búsqueda desacoplada lista para Semana 3.';

  @override
  Future<MaterialPage> search(
    MaterialSearchQuery query, {
    int page = 1,
    int pageSize = 10,
    CancelToken? cancelToken,
  }) async {
    final filters = [
      query.universityId,
      query.careerId,
      query.subjectId,
      query.professorId,
      query.type,
    ];
    if (filters.any((value) => value != null && value.trim().isNotEmpty) ||
        query.year != null ||
        page != 1 ||
        pageSize != 10) {
      throw SearchContractPendingException(
        message:
            'Los filtros, el orden y la paginación de Search están pendientes '
            'del contrato de INT2. No se envió una consulta parcial.',
      );
    }
    final text = query.text.trim();
    try {
      final response = await _client.dio.get<dynamic>(
        '/search',
        queryParameters: {if (text.isNotEmpty) 'q': text},
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['query'] != (text.isEmpty ? null : text) ||
          !data.containsKey('query') ||
          data['results'] is! List ||
          (data['results'] as List).isNotEmpty ||
          data['total'] is! int ||
          data['total'] != 0 ||
          data['message'] != stubMessage) {
        throw const FormatException('Respuesta de Search no acordada.');
      }
      // El stub devuelve [] aunque todavía no busca materiales. No convertirlo
      // en MaterialPage: total, fin de páginas e items reales aún no existen.
      throw SearchContractPendingException(
        message:
            'Search responde por Gateway, pero aún devuelve una simulación. '
            'La búsqueda de materiales está pendiente de INT2.',
        data: data,
      );
    } on DioException catch (error) {
      final intercepted = error.error;
      if (intercepted is ApiException) throw intercepted;
      throw ApiException.fromDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        message:
            'El servidor devolvió una respuesta de Search incompatible '
            'con el contrato disponible.',
        data: error,
      );
    }
  }
}
