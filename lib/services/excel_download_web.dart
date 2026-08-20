import 'dart:html' as html;
import 'dart:typed_data';

class ExcelDownload {
  static Future<String> kaydet({
    required String dosyaAdi,
    required List<int> bytes,
  }) async {
    final data = Uint8List.fromList(bytes);

    final blob = html.Blob(
      <dynamic>[data],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );

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