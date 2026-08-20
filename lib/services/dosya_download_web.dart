import 'dart:html' as html;
import 'dart:typed_data';

class DosyaDownload {
  static Future<String> kaydet({
    required String dosyaAdi,
    required List<int> bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    final blob = html.Blob(<dynamic>[Uint8List.fromList(bytes)], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = dosyaAdi
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return dosyaAdi;
  }
}
