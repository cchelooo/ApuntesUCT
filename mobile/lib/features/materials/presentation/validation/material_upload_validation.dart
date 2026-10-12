import 'dart:typed_data';

/// Reglas de validación del formulario de subida (issue #280).
///
/// Réplica del contrato de Material Service (`CreateMaterialDto`):
/// 5 MIME permitidos, máximo 15 MB inclusivo, año YYYY, tipo enum y la
/// relación tipo ↔ fuente (LINK exige enlace y no admite archivo).
/// Es Dart puro (sin Flutter) para poder probarse sin widgets.
abstract final class MaterialUploadValidation {
  /// 15 MB en bytes (límite inclusivo: exactamente 15 MB se acepta).
  static const int maxFileSizeBytes = 15 * 1024 * 1024;

  /// Extensiones aceptadas en el selector (file_picker las filtra).
  static const List<String> allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
  ];

  /// MIME oficiales del backend por extensión.
  static const Map<String, String> mimeByExtension = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  /// Códigos de tipo del backend con etiqueta visible en español.
  /// El orden de la lista no altera el orden oficial del formulario.
  static const List<MaterialUploadType> materialTypes = [
    MaterialUploadType(code: 'DOCUMENT', label: 'Documento'),
    MaterialUploadType(code: 'PRESENTATION', label: 'Presentación'),
    MaterialUploadType(code: 'EXAM', label: 'Examen / Certamen'),
    MaterialUploadType(code: 'SUMMARY', label: 'Resumen / Apunte'),
    MaterialUploadType(code: 'LINK', label: 'Enlace externo'),
  ];

  static bool isLinkType(String? typeCode) =>
      typeCode != null && typeCode.toUpperCase() == 'LINK';

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static String mimeForExtension(String extension) =>
      mimeByExtension[extension.toLowerCase()] ??
      'application/octet-stream';

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double value = bytes.toDouble();
    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Título obligatorio con mínimo de 3 caracteres visibles.
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El título es obligatorio.';
    }
    if (value.trim().length < 3) {
      return 'El título debe tener al menos 3 caracteres.';
    }
    return null;
  }

  /// Año YYYY según el contrato: ^(19|20)\d{2}$.
  static String? validateYear(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El año es obligatorio.';
    }
    if (!RegExp(r'^(19|20)\d{2}$').hasMatch(value.trim())) {
      return 'Ingresa un año válido (ej. 2026).';
    }
    return null;
  }

  /// URL http/https válida para enlace externo / respaldo.
  static String? validateExternalLink(String? value, {bool required = true}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return required ? 'Ingresa el enlace externo (https://...).' : null;
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return 'Ingresa una URL válida (https://...).';
    }
    return null;
  }

  /// Valida nombre y tamaño ya conocidos del archivo elegido.
  /// Retorna el mensaje de error o null si es válido.
  static String? validatePickedFile({
    required String fileName,
    required int sizeBytes,
  }) {
    final ext = extensionOf(fileName);
    if (!allowedExtensions.contains(ext)) {
      return 'Formato no permitido. Usa PDF, Word o PowerPoint.';
    }
    if (sizeBytes > maxFileSizeBytes) {
      return 'El archivo supera el límite de 15 MB.';
    }
    return null;
  }

  /// Coherencia tipo ↔ fuente según el contrato:
  /// LINK no admite archivo; los demás exigen archivo.
  static String? validateTypeAgainstSource({
    required String? typeCode,
    required bool isFileSource,
  }) {
    if (typeCode == null) return null;
    if (isLinkType(typeCode) && isFileSource) {
      return 'El tipo Enlace externo no admite archivo. '
          'Cambia la fuente a Enlace.';
    }
    if (!isLinkType(typeCode) && !isFileSource) {
      return 'Este tipo requiere un archivo. '
          'Cambia la fuente a Archivo o el tipo a Enlace externo.';
    }
    return null;
  }
}

/// Código de tipo del backend + etiqueta visible.
class MaterialUploadType {
  final String code;
  final String label;

  const MaterialUploadType({required this.code, required this.label});
}

/// Archivo ya elegido en el dispositivo (nombre + tamaño conocidos).
/// Los bytes pueden estar vacíos en plataformas que solo exponen el tamaño;
/// para la maqueta #280 basta nombre y tamaño (el envío real llega en #285).
class MaterialPickedFile {
  final String fileName;
  final int sizeBytes;
  final String mimeType;
  final Uint8List bytes;

  MaterialPickedFile({
    required this.fileName,
    required this.sizeBytes,
    required this.mimeType,
    Uint8List? bytes,
  }) : bytes = bytes ?? Uint8List(0);
}
