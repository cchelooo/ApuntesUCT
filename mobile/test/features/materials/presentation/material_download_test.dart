import 'dart:async';
import 'dart:typed_data';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_file_handler.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_detail_response.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/material_download_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_download_actions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final sampleDownload = MaterialDownload(
  bytes: Uint8List.fromList([0, 255, 128, 13]),
  fileName: 'Guía.pdf',
  mimeType: 'application/pdf',
);

class Adapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody(
      Stream.value(Uint8List.fromList(sampleDownload.bytes)),
      200,
      headers: {
        'content-type': ['application/pdf'],
        'content-disposition': [
          "attachment; filename=\"Guia.pdf\"; filename*=UTF-8''Gu%C3%ADa.pdf",
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class Repository extends DioMaterialRepository {
  Repository() : super(ApiClient());
  int calls = 0;
  String? requestedVersion;
  Future<MaterialDownload> Function()? response;
  @override
  Future<MaterialDownload> download(
    String id, {
    String? versionId,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    calls++;
    requestedVersion = versionId;
    return response?.call() ?? Future.value(downloadData);
  }

  MaterialDownload get downloadData => sampleDownload;
}

class Files implements MaterialFileHandler {
  Object? saveError, openError;
  int saves = 0;
  String? openedPath, openedMime;
  @override
  Future<String> save(MaterialDownload data) async {
    saves++;
    if (saveError != null) throw saveError!;
    return '/cache/material-test/Guía.pdf';
  }

  @override
  Future<void> open(String path, String mimeType) async {
    openedPath = path;
    openedMime = mimeType;
    if (openError != null) throw openError!;
  }
}

ProviderContainer containerFor(Repository repo, Files files) =>
    ProviderContainer(
      overrides: [
        dioMaterialRepositoryProvider.overrideWithValue(repo),
        materialFileHandlerProvider.overrideWithValue(files),
      ],
    );
Future<void> mount(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: MaterialDownloadActions(
            materialId: 'material-id',
            versionId: 'version-id',
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final type in ['DOCUMENT', 'LINK']) {
    testWidgets(
      'Detalle $type usa la versión del DTO y las acciones correctas',
      (tester) async {
        final repo = Repository();
        final files = Files();
        final container = containerFor(repo, files);
        addTearDown(container.dispose);
        final detail = materialDetailFromResponse({
          'id': 'material-id',
          'title': 'Guía de prueba',
          'materialType': type,
          'status': 'PUBLISHED',
          'currentVersion': type == 'LINK'
              ? null
              : {
                  'id': 'version-id',
                  'versionNumber': 2,
                  'originalFilename': 'Guía.pdf',
                  'mimeType': 'application/pdf',
                  'fileSize': '4',
                },
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: MaterialDetailScreen(detail: detail)),
          ),
        );
        if (type == 'LINK') {
          expect(find.text('Descargar Material'), findsNothing);
        } else {
          await tester.ensureVisible(find.text('Descargar Material'));
          await tester.tap(find.text('Descargar Material'));
          await tester.pumpAndSettle();
          expect(repo.requestedVersion, 'version-id');
          expect(find.text('Abrir archivo'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('URI completa, versión, RFC5987 y bytes binarios', () async {
    final adapter = Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
      ..httpClientAdapter = adapter;
    final result = await DioMaterialRepository(ApiClient(customDio: dio))
        .download('material-id', versionId: 'version-id');
    expect(
      adapter.request!.uri.toString(),
      'http://localhost:3000/api/v1/materials/material-id/download?versionId=version-id',
    );
    expect(adapter.request!.responseType, ResponseType.bytes);
    expect(result.fileName, 'Guía.pdf');
    expect(result.bytes, [0, 255, 128, 13]);
    expect(result.mimeType, 'application/pdf');
  });
  test(
    'Notifier real bloquea concurrencia y conserva material y versión',
    () async {
      final repo = Repository();
      final files = Files();
      final pending = Completer<MaterialDownload>();
      repo.response = () => pending.future;
      final container = containerFor(repo, files);
      addTearDown(container.dispose);
      final notifier = container.read(materialDownloadProvider.notifier);
      final first = notifier.download('material-id', versionId: 'version-id');
      expect(container.read(materialDownloadProvider).isLoading, isTrue);
      expect(await notifier.download('material-id'), isNull);
      expect(repo.calls, 1);
      pending.complete(sampleDownload);
      final result = (await first)!;
      expect(result.materialId, 'material-id');
      expect(result.versionId, 'version-id');
      expect(result.savedPath, '/cache/material-test/Guía.pdf');
      expect(files.saves, 1);
    },
  );
  testWidgets('Descarga bloquea botón y luego abre el archivo guardado', (
    tester,
  ) async {
    final repo = Repository();
    final files = Files();
    final pending = Completer<MaterialDownload>();
    repo.response = () => pending.future;
    final container = containerFor(repo, files);
    addTearDown(container.dispose);
    await mount(tester, container);
    await tester.tap(find.text('Descargar Material'));
    await tester.pump();
    expect(find.text('Descargando material...'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repo.calls, 1);
    expect(repo.requestedVersion, 'version-id');
    pending.complete(sampleDownload);
    await tester.pumpAndSettle();
    expect(find.text('Descarga completada: Guía.pdf'), findsOneWidget);
    await tester.tap(find.text('Abrir archivo'));
    await tester.pumpAndSettle();
    expect(files.openedPath, '/cache/material-test/Guía.pdf');
    expect(files.openedMime, 'application/pdf');
  });
  testWidgets('Error de disco no anuncia éxito y permite reintentar', (
    tester,
  ) async {
    final repo = Repository();
    final files = Files()
      ..saveError = const MaterialFileException(
        'No se pudo guardar el archivo.',
      );
    final container = containerFor(repo, files);
    addTearDown(container.dispose);
    await mount(tester, container);
    await tester.tap(find.text('Descargar Material'));
    await tester.pumpAndSettle();
    expect(container.read(materialDownloadProvider).hasError, isTrue);
    expect(find.text('Descarga completada: Guía.pdf'), findsNothing);
    expect(find.text('Abrir archivo'), findsNothing);
    expect(find.text('No se pudo guardar el archivo.'), findsWidgets);
    files.saveError = null;
    await tester.tap(find.text('Reintentar descarga'));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('Abrir archivo'), findsOneWidget);
  });
  testWidgets('Error de apertura permite reintentar sin volver a descargar', (
    tester,
  ) async {
    final repo = Repository();
    final files = Files()
      ..openError = const MaterialFileException(
        'No hay aplicación para este formato.',
      );
    final container = containerFor(repo, files);
    addTearDown(container.dispose);
    await mount(tester, container);
    await tester.tap(find.text('Descargar Material'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir archivo'));
    await tester.pumpAndSettle();
    expect(find.text('No hay aplicación para este formato.'), findsOneWidget);
    expect(container.read(materialDownloadProvider).hasValue, isTrue);
    files.openError = null;
    await tester.tap(find.text('Abrir archivo'));
    await tester.pumpAndSettle();
    expect(find.text('No hay aplicación para este formato.'), findsNothing);
    expect(repo.calls, 1);
  });
  for (final status in [401, 404]) {
    testWidgets('HTTP $status no guarda ni ofrece abrir', (tester) async {
      final repo = Repository()
        ..response = () async =>
            throw ApiException(message: 'HTTP error', statusCode: status);
      final files = Files();
      final container = containerFor(repo, files);
      addTearDown(container.dispose);
      await mount(tester, container);
      await tester.tap(find.text('Descargar Material'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          status == 401
              ? 'Tu sesión no es válida. Vuelve a iniciar sesión.'
              : 'El archivo ya no está disponible.',
        ),
        findsWidgets,
      );
      expect(files.saves, 0);
      expect(find.text('Abrir archivo'), findsNothing);
    });
  }
  testWidgets('No abre el archivo de otro material', (tester) async {
    final repo = Repository();
    final files = Files();
    final container = containerFor(repo, files);
    addTearDown(container.dispose);
    await container
        .read(materialDownloadProvider.notifier)
        .download('other-id');
    await mount(tester, container);
    expect(find.text('Abrir archivo'), findsNothing);
  });
}
