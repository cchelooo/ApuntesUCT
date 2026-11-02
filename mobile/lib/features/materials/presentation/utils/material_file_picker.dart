import 'package:apuntesuct_mobile/features/materials/presentation/validation/material_upload_validation.dart';
import 'package:file_picker/file_picker.dart';

/// Selector nativo de archivo (PDF, Word, PowerPoint) compatible con
/// Android/iOS, compartido por la subida de material (#285) y la subida de
/// nueva versión (#292).
///
/// Retorna null si el usuario cancela. Lee los bytes reales salvo que el
/// tamaño ya exceda el límite (la validación lo rechaza sin leer). Un fallo
/// de lectura lanza y el llamador lo convierte en error mostrable.
Future<MaterialPickedFile?> pickMaterialFile() async {
  final f = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: MaterialUploadValidation.allowedExtensions,
  );
  if (f == null) return null;
  final size = f.lengthSync() ?? await f.length() ?? 0;
  final mimeType = MaterialUploadValidation.mimeForExtension(
    MaterialUploadValidation.extensionOf(f.name),
  );
  if (size > MaterialUploadValidation.maxFileSizeBytes ||
      !MaterialUploadValidation.allowedExtensions.contains(
        MaterialUploadValidation.extensionOf(f.name),
      )) {
    return MaterialPickedFile(
      fileName: f.name,
      sizeBytes: size,
      mimeType: mimeType,
    );
  }
  final bytes = await f.readAsBytes();
  return MaterialPickedFile(
    fileName: f.name,
    sizeBytes: bytes.length,
    mimeType: mimeType,
    bytes: bytes,
  );
}
