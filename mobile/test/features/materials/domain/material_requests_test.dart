import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la subida y descarga conservan su contenido si se modifica la lista original', () {
    final bytes = [1, 2, 3];
    final source = LocalMaterialFile(
      fileName: 'apunte.pdf',
      mimeType: 'application/pdf',
      bytes: bytes,
    );
    final download = MaterialDownload(
      fileName: 'apunte.pdf',
      mimeType: 'application/pdf',
      bytes: bytes,
    );
    bytes.clear();
    expect(source.bytes, [1, 2, 3]);
    expect(download.bytes, [1, 2, 3]);
    expect(() => source.bytes.add(4), throwsUnsupportedError);
    expect(() => download.bytes.add(4), throwsUnsupportedError);
  });
}
