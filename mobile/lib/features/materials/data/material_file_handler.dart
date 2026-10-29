import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models/material_requests.dart';

class MaterialFileException implements Exception {
  const MaterialFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class MaterialFileHandler {
  Future<String> save(MaterialDownload download);
  Future<void> open(String path, String mimeType);
}

/// Guarda cada descarga en su propio directorio de caché de la aplicación.
/// El nombre recibido del servidor nunca puede convertirse en una ruta.
class NativeMaterialFileHandler implements MaterialFileHandler {
  NativeMaterialFileHandler({
    Future<Directory> Function()? temporaryDirectory,
    Future<OpenResult> Function(String path, String mimeType)? opener,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _opener = opener ?? _openNative;

  final Future<Directory> Function() _temporaryDirectory;
  final Future<OpenResult> Function(String, String) _opener;

  static Future<OpenResult> _openNative(String path, String mimeType) =>
      OpenFilex.open(path, type: mimeType);

  @override
  Future<String> save(MaterialDownload download) async {
    Directory? directory;
    try {
      final cache = await _temporaryDirectory();
      directory = await cache.createTemp('material-');
      final basename = download.fileName
          .split(RegExp(r'[/\\]'))
          .last
          .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
          .trim();
      final name = basename.isEmpty || basename == '.' || basename == '..'
          ? 'material_descargado'
          : basename;
      final file = File('${directory.path}/$name');
      await file.writeAsBytes(download.bytes, flush: true);
      return file.path;
    } catch (_) {
      if (directory != null) {
        try {
          await directory.delete(recursive: true);
        } catch (_) {
          // La limpieza no debe reemplazar el error de guardado.
        }
      }
      throw const MaterialFileException(
        'No se pudo guardar el archivo. Revisa el espacio disponible y los permisos.',
      );
    }
  }

  @override
  Future<void> open(String path, String mimeType) async {
    try {
      final result = await _opener(path, mimeType);
      if (result.type == ResultType.done) return;
      throw MaterialFileException(switch (result.type) {
        ResultType.noAppToOpen =>
          'No hay una aplicación instalada para abrir este formato.',
        ResultType.fileNotFound =>
          'El archivo temporal ya no está disponible. Descárgalo nuevamente.',
        ResultType.permissionDenied =>
          'No se pudo abrir el archivo por falta de permisos.',
        _ => 'No se pudo abrir el archivo. Puedes intentarlo nuevamente.',
      });
    } on MaterialFileException {
      rethrow;
    } catch (_) {
      throw const MaterialFileException(
        'No se pudo abrir el archivo. Puedes intentarlo nuevamente.',
      );
    }
  }
}
