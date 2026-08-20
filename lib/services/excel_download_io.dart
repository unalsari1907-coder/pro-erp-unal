import 'dart:io';

import 'package:file_picker/file_picker.dart';

class ExcelDownload {
  static Future<String> kaydet({
    required String dosyaAdi,
    required List<int> bytes,
  }) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Excel Dosyasını Kaydet',
      fileName: dosyaAdi,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );

    if (path == null || path.trim().isEmpty) {
      return dosyaAdi;
    }

    await File(path).writeAsBytes(
      bytes,
      flush: true,
    );

    return path;
  }
}