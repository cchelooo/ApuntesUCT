import 'dart:convert';

import 'package:dio/dio.dart';

/// Transporte controlado: captura el stream enviado sin acceder a la red.
class MaterialHttpAdapter implements HttpClientAdapter {
  MaterialHttpAdapter(this.response, {this.status = 201, this.failure});
  final Object? response;
  final int status;
  final DioExceptionType? failure;
  final requests = <RequestOptions>[];
  List<int> body = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    if (requestStream != null) {
      body = await requestStream.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
