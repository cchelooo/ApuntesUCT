import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_search_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_search_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class StubSearchAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'query': options.queryParameters['q'],
        'results': [],
        'total': 0,
        'message': DioSearchRepository.stubMessage,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'stub real por cliente central es integración pendiente, no página vacía',
    () async {
      final adapter = StubSearchAdapter();
      final dio = Dio(
        BaseOptions(baseUrl: 'https://central.example.test/api/v1'),
      )..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final client = ApiClient(customDio: dio);
      final container = ProviderContainer(
        overrides: [apiclientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      await container
          .read(materialSearchControllerProvider.notifier)
          .search(const MaterialSearchQuery(text: '  álgebra  '));
      final state = container.read(materialSearchControllerProvider);
      expect(
        state.result!.asError!.error,
        isA<SearchContractPendingException>(),
      );
      expect(state.result!.asData, isNull);
      expect(
        adapter.requests.single.uri.toString(),
        'https://central.example.test/api/v1/search?q=%C3%A1lgebra',
      );
    },
  );
}
