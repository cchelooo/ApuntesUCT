import 'dart:io';

import 'package:apuntesuct_mobile/features/materials/data/material_file_handler.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart';

void main() {
  late Directory cache;
  setUp(() async {
    cache = await Directory.systemTemp.createTemp('material-test-');
  });
  tearDown(() async {
    await cache.delete(recursive: true);
  });
  MaterialDownload data(String name) => MaterialDownload(
    fileName: name,
    mimeType: 'application/pdf',
    bytes: [0, 255, 128, 13],
  );
  test(
    'Guarda bytes y Unicode sin sobrescribir descargas del mismo nombre',
    () async {
      final handler = NativeMaterialFileHandler(
        temporaryDirectory: () async => cache,
      );
      final first = await handler.save(data('Guía.pdf'));
      final second = await handler.save(data('Guía.pdf'));
      expect(first, isNot(second));
      expect(first.endsWith('/Guía.pdf'), isTrue);
      expect(await File(first).readAsBytes(), [0, 255, 128, 13]);
      expect(await File(second).readAsBytes(), [0, 255, 128, 13]);
    },
  );
  test('Nombre del servidor no escapa del directorio de descarga', () async {
    final handler = NativeMaterialFileHandler(
      temporaryDirectory: () async => cache,
    );
    for (final name in ['../../Guía.pdf', r'..\..\Guía.pdf', '..', '\u0000']) {
      final path = await handler.save(data(name));
      expect(File(path).parent.parent.path, cache.path);
      expect(await File(path).exists(), isTrue);
    }
  });
  test('Error real de filesystem se propaga sin anunciar éxito', () async {
    final blocker = File('${cache.path}/blocker');
    await blocker.writeAsString('occupied');
    final handler = NativeMaterialFileHandler(
      temporaryDirectory: () async => Directory(blocker.path),
    );
    await expectLater(
      handler.save(data('Guía.pdf')),
      throwsA(isA<MaterialFileException>()),
    );
    expect(await blocker.readAsString(), 'occupied');
  });
  test('Entrega ruta y MIME al abridor nativo', () async {
    String? openedPath, openedMime;
    final handler = NativeMaterialFileHandler(
      opener: (path, mime) async {
        openedPath = path;
        openedMime = mime;
        return OpenResult();
      },
    );
    await handler.open('/cache/Guía.pdf', 'application/pdf');
    expect(openedPath, '/cache/Guía.pdf');
    expect(openedMime, 'application/pdf');
  });
  for (final type in [
    ResultType.noAppToOpen,
    ResultType.fileNotFound,
    ResultType.permissionDenied,
    ResultType.error,
  ]) {
    test('Resultado nativo $type se informa como error', () async {
      final handler = NativeMaterialFileHandler(
        opener: (_, _) async => OpenResult(type: type),
      );
      await expectLater(
        handler.open('/cache/file.pdf', 'application/pdf'),
        throwsA(isA<MaterialFileException>()),
      );
    });
  }
}
