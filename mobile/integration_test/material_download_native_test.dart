import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_file_handler.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_download_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_download_actions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Transporte controlado; caché y visor usan los plugins reales del dispositivo.
class _PdfAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.uri.path, '/api/v1/materials/test-material/download');
    expect(options.queryParameters['versionId'], 'test-version');
    return ResponseBody(
      Stream.value(_pdf()),
      200,
      headers: {
        'content-type': ['application/pdf'],
        'content-disposition': ["attachment; filename*=UTF-8''Gu%C3%ADa.pdf"],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Uint8List _pdf() {
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> >>',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buffer.length);
    buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = buffer.length;
  buffer.write('xref\n0 4\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write('trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return Uint8List.fromList(ascii.encode(buffer.toString()));
}

class _NativeFiles implements MaterialFileHandler {
  final delegate = NativeMaterialFileHandler();
  bool opened = false;
  MaterialFileException? error;

  @override
  Future<String> save(MaterialDownload download) => delegate.save(download);

  @override
  Future<void> open(String path, String mimeType) async {
    try {
      await delegate.open(path, mimeType);
      opened = true;
    } on MaterialFileException catch (exception) {
      error = exception;
      rethrow;
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Descarga y apertura nativa desde la acción visible', (
    tester,
  ) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
      ..httpClientAdapter = _PdfAdapter();
    final files = _NativeFiles();
    final container = ProviderContainer(
      overrides: [
        dioMaterialRepositoryProvider.overrideWithValue(
          DioMaterialRepository(ApiClient(customDio: dio)),
        ),
        materialFileHandlerProvider.overrideWithValue(files),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: MaterialDownloadActions(
                  materialId: 'test-material',
                  versionId: 'test-version',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Descargar Material'));
    await tester.pumpAndSettle();
    // I/O nativo puede terminar después de que dejen de existir frames pendientes.
    for (
      var i = 0;
      i < 100 && container.read(materialDownloadProvider).isLoading;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    final result = container.read(materialDownloadProvider).requireValue!;
    expect(result.savedPath.endsWith('/Guía.pdf'), isTrue);
    expect(await File(result.savedPath).readAsBytes(), _pdf());
    expect(find.text('Abrir archivo'), findsOneWidget);
    await tester.tap(find.text('Abrir archivo'));
    for (var i = 0; i < 100 && !files.opened && files.error == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    if (files.error != null) {
      // Un dispositivo sin visor debe recibir el mensaje concreto, no falso éxito.
      expect(
        files.error!.message,
        'No hay una aplicación instalada para abrir este formato.',
      );
      expect(find.text(files.error!.message), findsOneWidget);
    } else {
      expect(files.opened, isTrue);
    }
    expect(tester.takeException(), isNull);
    // ignore: avoid_print
    print(
      'Apertura nativa: ${files.opened ? 'visor iniciado' : files.error!.message}',
    );
  });
}
