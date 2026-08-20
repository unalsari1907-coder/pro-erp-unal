import 'dart:io';

import 'package:file_picker/file_picker.dart';

class DosyaDownload {
  static Future<String> kaydet({
    required String dosyaAdi,
    required List<int> bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    final uzanti = dosyaAdi.contains('.') ? dosyaAdi.split('.').last : 'dat';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Yedek Dosyasını Kaydet',
      fileName: dosyaAdi,
      type: FileType.custom,
      allowedExtensions: [uzanti],
    );
    if (path == null || path.trim().isEmpty) return dosyaAdi;
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
