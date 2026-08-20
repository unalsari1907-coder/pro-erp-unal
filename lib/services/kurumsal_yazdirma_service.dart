import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/stok_model.dart';
import 'firma_ayarlari_service.dart';

class KurumsalYazdirmaService {
  KurumsalYazdirmaService._();

  static double _d(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().replaceAll(',', '.') ?? '0') ?? 0;

  static String _metin(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  static String _para(dynamic value) => '${_d(value).toStringAsFixed(2)} TL';

  static String _miktar(dynamic value) {
    final d = _d(value);
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(3);
  }

  static String _tarih(dynamic value) {
    final raw = value?.toString() ?? '';
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return raw.trim().isEmpty ? '-' : raw;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static Future<List<pw.Font>> _fonts() async {
    return [
      await PdfGoogleFonts.notoSansRegular(),
      await PdfGoogleFonts.notoSansBold(),
    ];
  }

  static pw.Widget _firmaBaslik({
    required FirmaAyarlari firma,
    required String belgeBasligi,
    required pw.Font bold,
  }) {
    final adres = [firma.adres, firma.ilce, firma.il]
        .where((e) => e.trim().isNotEmpty)
        .join(' / ');
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  firma.unvan,
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
                if (adres.isNotEmpty)
                  pw.Text(adres, style: const pw.TextStyle(fontSize: 8)),
                if (firma.telefon.isNotEmpty)
                  pw.Text('Tel: ${firma.telefon}', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
            pw.Text(
              belgeBasligi,
              style: pw.TextStyle(font: bold, fontSize: 15),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Sayfa ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      );

  static Future<void> siparisYazdir({
    required bool satis,
    required Map<String, dynamic> siparis,
    required List<Map<String, dynamic>> detaylar,
  }) async {
    final bytes = await _siparisPdf(
      satis: satis,
      siparis: siparis,
      detaylar: detaylar,
    );
    await Printing.layoutPdf(
      name: '${satis ? 'Satis' : 'Alis'} Siparisi ${_metin(siparis['siparis_no'])}',
      format: PdfPageFormat.a4.landscape,
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> _siparisPdf({
    required bool satis,
    required Map<String, dynamic> siparis,
    required List<Map<String, dynamic>> detaylar,
  }) async {
    final firma = await FirmaAyarlariService.getir();
    final fonts = await _fonts();
    final regular = fonts[0];
    final bold = fonts[1];
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    double ara = 0;
    double indirim = 0;
    double kdv = 0;
    final rows = <List<String>>[];

    for (final d in detaylar) {
      final brut = _d(d['miktar']) * _d(d['birim_fiyat']);
      final ind = brut * _d(d['indirim_orani']) / 100;
      final matrah = brut - ind;
      final satirKdv = matrah * _d(d['kdv_orani']) / 100;
      ara += brut;
      indirim += ind;
      kdv += satirKdv;
      rows.add([
        _metin(d['urun_adi']),
        _metin(d['uretici_kodu']),
        _metin(d['raf']),
        _miktar(d['miktar']),
        _miktar(satis ? d['sevk_edilen_miktar'] : d['kabul_edilen_miktar']),
        _miktar(d['kalan_miktar']),
        _para(d['birim_fiyat']),
        _d(d['indirim_orani']).toStringAsFixed(0),
        _d(d['kdv_orani']).toStringAsFixed(0),
        _para(matrah + satirKdv),
      ]);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _firmaBaslik(
          firma: firma,
          belgeBasligi: satis ? 'SATIŞ SİPARİŞİ' : 'ALIŞ SİPARİŞİ',
          bold: bold,
        ),
        footer: _footer,
        build: (_) => [
          pw.Wrap(
            spacing: 24,
            runSpacing: 5,
            children: [
              pw.Text('Sipariş No: ${_metin(siparis['siparis_no'])}', style: pw.TextStyle(font: bold)),
              pw.Text('Tarih: ${_tarih(siparis['tarih'])}'),
              pw.Text('Cari: ${_metin(siparis['cari_unvan'])}'),
              pw.Text('Depo: ${_metin(siparis['depo_adi'])}'),
              pw.Text('Durum: ${_metin(siparis['durum'])}'),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: const [
              'Ürün', 'Kod', 'RAF', 'Miktar', 'İşlenen', 'Kalan',
              'Birim Fiyat', 'İnd.%', 'KDV%', 'Toplam'
            ],
            data: rows,
            headerStyle: pw.TextStyle(font: bold, fontSize: 8.5),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3.2),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(0.8),
              3: pw.FlexColumnWidth(0.8),
              4: pw.FlexColumnWidth(0.9),
              5: pw.FlexColumnWidth(0.8),
              6: pw.FlexColumnWidth(1.2),
              7: pw.FlexColumnWidth(0.7),
              8: pw.FlexColumnWidth(0.7),
              9: pw.FlexColumnWidth(1.3),
            },
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Ara Toplam: ${_para(ara)}'),
                if (indirim > 0) pw.Text('İndirim: ${_para(indirim)}'),
                pw.Text('KDV: ${_para(kdv)}'),
                pw.SizedBox(height: 3),
                pw.Text(
                  'GENEL TOPLAM: ${_para(ara - indirim + kdv)}',
                  style: pw.TextStyle(font: bold, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> makbuzYazdir(Map<String, dynamic> makbuz) async {
    final firma = await FirmaAyarlariService.getir();
    final fonts = await _fonts();
    final regular = fonts[0];
    final bold = fonts[1];
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final tahsilat = _metin(makbuz['makbuz_turu']).toUpperCase() == 'TAHSILAT';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _firmaBaslik(
              firma: firma,
              belgeBasligi: tahsilat ? 'TAHSİLAT MAKBUZU' : 'ÖDEME MAKBUZU',
              bold: bold,
            ),
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
              columnWidths: const {0: pw.FixedColumnWidth(145), 1: pw.FlexColumnWidth()},
              children: [
                for (final item in <List<String>>[
                  ['Belge No', _metin(makbuz['belge_no'])],
                  ['Tarih / Saat', _tarih(makbuz['tarih'])],
                  ['Cari', _metin(makbuz['cari_unvan'])],
                  ['Cari Tipi', _metin(makbuz['cari_tipi'])],
                  ['Ödeme Türü', _metin(makbuz['odeme_turu'] ?? makbuz['odeme_tipi'])],
                  ['Kasa / Banka / POS', _metin(makbuz['kasa_adi'])],
                  ['Tutar', _para(makbuz['tutar'])],
                  ['Açıklama', _metin(makbuz['aciklama'])],
                  ['Kullanıcı', _metin(makbuz['kullanici'])],
                ])
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(7),
                        child: pw.Text(item[0], style: pw.TextStyle(font: bold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(7),
                        child: pw.Text(item[1], style: const pw.TextStyle(fontSize: 9)),
                      ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 35),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _imzaKutusu('Düzenleyen'),
                _imzaKutusu(tahsilat ? 'Teslim Eden' : 'Teslim Alan'),
              ],
            ),
            pw.Spacer(),
            _footer(context),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(
      name: '${tahsilat ? 'Tahsilat' : 'Odeme'} Makbuzu ${_metin(makbuz['belge_no'])}',
      format: PdfPageFormat.a4,
      onLayout: (_) async => bytes,
    );
  }

  static pw.Widget _imzaKutusu(String baslik) => pw.Container(
        width: 190,
        height: 80,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(baslik, style: const pw.TextStyle(fontSize: 9)),
      );

  static Future<void> stokKartiYazdir(StokModel stok) async {
    final firma = await FirmaAyarlariService.getir();
    final fonts = await _fonts();
    final regular = fonts[0];
    final bold = fonts[1];
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _firmaBaslik(firma: firma, belgeBasligi: 'STOK KARTI', bold: bold),
            pw.SizedBox(height: 12),
            pw.Text(stok.urunAdi, style: pw.TextStyle(font: bold, fontSize: 15)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {0: pw.FixedColumnWidth(150), 1: pw.FlexColumnWidth()},
              children: [
                for (final item in <List<String>>[
                  ['Üretici Kodu', stok.ureticiKodu],
                  ['Marka', stok.marka],
                  ['Model', stok.model],
                  ['OEM Kodları', stok.oemNo],
                  ['Cross Kodlar', stok.cross],
                  ['Rakip Kodlar', stok.rakipKod],
                  ['Araçlar', stok.arac],
                  ['Barkod', stok.barkod],
                  ['RAF', stok.raf],
                  ['Stok Miktarı', _miktar(stok.stokMiktari)],
                  ['Minimum Stok', _miktar(stok.minimumStok)],
                  ['Alış Fiyatı', _para(stok.alisFiyati)],
                  ['Perakende Satış', _para(stok.satisFiyatiPerakende)],
                  ['Toptan Satış', _para(stok.satisFiyatiToptan)],
                  ['KDV', '%${stok.kdv.toStringAsFixed(0)}'],
                  ['Ürün Özelliği', stok.urunOzellik],
                  ['Açıklama', stok.aciklama],
                ])
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(item[0], style: pw.TextStyle(font: bold, fontSize: 8.5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(_metin(item[1]), style: const pw.TextStyle(fontSize: 8.5)),
                      ),
                    ],
                  ),
              ],
            ),
            pw.Spacer(),
            _footer(context),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(
      name: 'Stok Karti ${stok.ureticiKodu}',
      format: PdfPageFormat.a4,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> stokEtiketiYazdir({
    required String urunAdi,
    required String ureticiKodu,
    required String barkod,
    required String raf,
  }) async {
    final fonts = await _fonts();
    final regular = fonts[0];
    final bold = fonts[1];
    final format = PdfPageFormat(
      100 * PdfPageFormat.mm,
      60 * PdfPageFormat.mm,
    );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.all(5 * PdfPageFormat.mm),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(_metin(urunAdi), maxLines: 2, style: pw.TextStyle(font: bold, fontSize: 11)),
            pw.SizedBox(height: 5),
            pw.Text('Kod: ${_metin(ureticiKodu)}', style: pw.TextStyle(font: bold, fontSize: 10)),
            if (barkod.trim().isNotEmpty) pw.Text('Barkod: $barkod', style: const pw.TextStyle(fontSize: 9)),
            if (raf.trim().isNotEmpty) pw.Text('RAF: $raf', style: pw.TextStyle(font: bold, fontSize: 10)),
          ],
        ),
      ),
    );
    final bytes = await doc.save();
    await Printing.layoutPdf(
      name: 'Stok Etiketi ${_metin(ureticiKodu)}',
      format: format,
      onLayout: (_) async => bytes,
    );
  }
}
