import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'excel_download.dart';
import 'firma_ayarlari_service.dart';
import 'supabase_service.dart';

class CariEkstreService {
  CariEkstreService._();

  static double _sayi(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().replaceAll(',', '.') ?? '0') ?? 0;

  static String _para(dynamic value) => '${_sayi(value).toStringAsFixed(2)} TL';

  static double gosterimBorc(Map<String, dynamic> hareket) {
    final tip = (hareket['islem_tipi']?.toString() ?? '').trim().toUpperCase();
    if (tip == 'VIRMAN_TEDARIKCI' || tip == 'VİRMAN_TEDARİKÇİ') {
      return _sayi(hareket['borc']) + _sayi(hareket['alacak']);
    }
    return _sayi(hareket['borc']);
  }

  static double gosterimAlacak(Map<String, dynamic> hareket) {
    final tip = (hareket['islem_tipi']?.toString() ?? '').trim().toUpperCase();
    if (tip == 'VIRMAN_TEDARIKCI' || tip == 'VİRMAN_TEDARİKÇİ') return 0;
    return _sayi(hareket['alacak']);
  }

  static String tarih(dynamic value) {
    final tarih = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (tarih == null) return value?.toString() ?? '-';
    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.${tarih.year} '
        '${tarih.hour.toString().padLeft(2, '0')}:'
        '${tarih.minute.toString().padLeft(2, '0')}';
  }

  static String bakiyeMetni(double bakiye) {
    if (bakiye.abs() < 0.005) return '0.00';
    final yon = bakiye > 0 ? 'B' : 'A';
    return '${bakiye.abs().toStringAsFixed(2)} ($yon)';
  }

  static String islemTuru(Map<String, dynamic> hareket) {
    final raw = (hareket['islem_tipi']?.toString() ?? '').trim();
    final tip = raw.toUpperCase();

    if (tip == 'SATIS' || tip == 'SATIŞ') return 'Satış Faturası';
    if (tip == 'ALIS' || tip == 'ALIŞ') return 'Alış Faturası';
    if (tip.contains('SATIS_IADE') || tip.contains('SATIŞ_İADE')) {
      return 'Satış İadesi';
    }
    if (tip.contains('ALIS_IADE') || tip.contains('ALIŞ_İADE')) {
      return 'Alış İadesi';
    }
    if (tip == 'TAHSILAT' || tip == 'TAHSİLAT') return 'Tahsilat';
    if (tip == 'ODEME' || tip == 'ÖDEME') return 'Ödeme';
    if (tip.contains('VIRMAN') || tip.contains('VİRMAN')) {
      return 'Cari Virman / Mahsup';
    }
    if (tip.contains('MASRAF')) return 'Masraf / Gider';
    if (tip.contains('NAKLIYE') || tip.contains('NAKLİYE')) return 'Nakliye';
    if (tip.contains('IPTAL') || tip.contains('İPTAL')) {
      return raw.replaceAll('_', ' ');
    }
    return raw.isEmpty ? '-' : raw.replaceAll('_', ' ');
  }

  static String islemNo(Map<String, dynamic> hareket) {
    final belge = hareket['belge_no']?.toString().trim() ?? '';
    if (belge.isNotEmpty && belge != '-') return belge;
    final id = hareket['hareket_id']?.toString().trim() ?? '';
    return id.isEmpty ? '-' : id;
  }

  static String faturaNo(Map<String, dynamic> hareket) {
    final value = hareket['fatura_no']?.toString().trim() ?? '';
    return value.isEmpty ? '-' : value;
  }

  static String irsaliyeNo(Map<String, dynamic> hareket) {
    final value = hareket['irsaliye_no']?.toString().trim() ?? '';
    return value.isEmpty ? '-' : value;
  }

  static String _dosyaAdi(String unvan) {
    final temiz = unvan
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9ÇĞİÖŞÜ]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return temiz.isEmpty ? 'CARI' : temiz;
  }

  /// Cari hareketlerini fatura ve irsaliye numaralarıyla tamamlar.
  /// Eski hareket kayıtlarını değiştirmez; sadece ekranda/çıktıda kullanılacak
  /// kopyalara fatura_no ve irsaliye_no alanlarını ekler.
  static Future<List<Map<String, dynamic>>> belgeBilgileriniTamamla(
    List<Map<String, dynamic>> hareketler,
  ) async {
    final sonuc = hareketler.map((e) => Map<String, dynamic>.from(e)).toList();
    if (sonuc.isEmpty) return sonuc;

    try {
      final cariIds = sonuc
          .map((e) => int.tryParse(e['cari_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet()
          .toList();

      if (cariIds.isEmpty) return sonuc;

      final satisResponse = await SupabaseService.supabase
          .from('satis_baslik')
          .select('satis_id, cari_id, fatura_no, belge_no')
          .inFilter('cari_id', cariIds);
      final alisResponse = await SupabaseService.supabase
          .from('alis_baslik')
          .select('alis_id, cari_id, fatura_no')
          .inFilter('cari_id', cariIds);

      final satislar = List<Map<String, dynamic>>.from(satisResponse);
      final alislar = List<Map<String, dynamic>>.from(alisResponse);

      final satisAnahtar = <String, Map<String, dynamic>>{};
      for (final f in satislar) {
        final fatura = f['fatura_no']?.toString().trim() ?? '';
        final belge = f['belge_no']?.toString().trim() ?? '';
        if (fatura.isNotEmpty) satisAnahtar[fatura] = f;
        if (belge.isNotEmpty) satisAnahtar[belge] = f;
      }

      final alisAnahtar = <String, Map<String, dynamic>>{};
      for (final f in alislar) {
        final fatura = f['fatura_no']?.toString().trim() ?? '';
        if (fatura.isNotEmpty) alisAnahtar[fatura] = f;
      }

      final satisIrsaliyeMap = await _irsaliyeHaritasi(
        satis: true,
        faturaIds: satislar
            .map((e) => int.tryParse(e['satis_id']?.toString() ?? ''))
            .whereType<int>()
            .toList(),
      );
      final alisIrsaliyeMap = await _irsaliyeHaritasi(
        satis: false,
        faturaIds: alislar
            .map((e) => int.tryParse(e['alis_id']?.toString() ?? ''))
            .whereType<int>()
            .toList(),
      );

      for (final hareket in sonuc) {
        final tip = (hareket['islem_tipi']?.toString() ?? '').toUpperCase();
        final belgeNo = hareket['belge_no']?.toString().trim() ?? '';
        if (belgeNo.isEmpty) continue;

        if (tip.contains('SATIS') || tip.contains('SATIŞ')) {
          final f = satisAnahtar[belgeNo];
          if (f != null) {
            final id = int.tryParse(f['satis_id']?.toString() ?? '');
            hareket['fatura_no'] = f['fatura_no']?.toString() ?? belgeNo;
            hareket['irsaliye_no'] = id == null
                ? ''
                : (satisIrsaliyeMap[id] ?? const <String>[]).join(', ');
          }
        } else if (tip.contains('ALIS') || tip.contains('ALIŞ')) {
          final f = alisAnahtar[belgeNo];
          if (f != null) {
            final id = int.tryParse(f['alis_id']?.toString() ?? '');
            hareket['fatura_no'] = f['fatura_no']?.toString() ?? belgeNo;
            hareket['irsaliye_no'] = id == null
                ? ''
                : (alisIrsaliyeMap[id] ?? const <String>[]).join(', ');
          }
        }
      }
    } catch (_) {
      // Ekstre, ilişki tablolarından biri eski kurulumda yoksa da açılmaya
      // devam etsin. Mevcut hareket bilgileri kaybolmaz.
    }

    return sonuc;
  }

  static Future<Map<int, List<String>>> _irsaliyeHaritasi({
    required bool satis,
    required List<int> faturaIds,
  }) async {
    if (faturaIds.isEmpty) return {};

    try {
      final baglantiTablo =
          satis ? 'satis_irsaliye_fatura' : 'alis_irsaliye_fatura';
      final faturaIdKolonu = satis ? 'satis_id' : 'alis_id';
      final irsaliyeTablo =
          satis ? 'satis_irsaliye_baslik' : 'alis_irsaliye_baslik';

      final baglantilarResponse = await SupabaseService.supabase
          .from(baglantiTablo)
          .select('$faturaIdKolonu, irsaliye_id')
          .inFilter(faturaIdKolonu, faturaIds);
      final baglantilar = List<Map<String, dynamic>>.from(baglantilarResponse);

      final irsaliyeIds = baglantilar
          .map((e) => int.tryParse(e['irsaliye_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet()
          .toList();
      if (irsaliyeIds.isEmpty) return {};

      final irsaliyelerResponse = await SupabaseService.supabase
          .from(irsaliyeTablo)
          .select('irsaliye_id, irsaliye_no')
          .inFilter('irsaliye_id', irsaliyeIds);
      final irsaliyeler = List<Map<String, dynamic>>.from(irsaliyelerResponse);

      final noById = <int, String>{};
      for (final i in irsaliyeler) {
        final id = int.tryParse(i['irsaliye_id']?.toString() ?? '');
        final no = i['irsaliye_no']?.toString().trim() ?? '';
        if (id != null && no.isNotEmpty) noById[id] = no;
      }

      final sonuc = <int, List<String>>{};
      for (final b in baglantilar) {
        final faturaId = int.tryParse(b[faturaIdKolonu]?.toString() ?? '');
        final irsaliyeId = int.tryParse(b['irsaliye_id']?.toString() ?? '');
        if (faturaId == null || irsaliyeId == null) continue;
        final no = noById[irsaliyeId];
        if (no == null || no.isEmpty) continue;
        final liste = sonuc.putIfAbsent(faturaId, () => <String>[]);
        if (!liste.contains(no)) liste.add(no);
      }
      return sonuc;
    } catch (_) {
      return {};
    }
  }

  static List<Map<String, dynamic>> kronolojikHareketler(
    List<Map<String, dynamic>> hareketler,
  ) {
    final liste = hareketler.map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => (a['tarih']?.toString() ?? '')
          .compareTo(b['tarih']?.toString() ?? ''));

    double bakiye = 0;
    for (final hareket in liste) {
      final borc = gosterimBorc(hareket);
      final alacak = gosterimAlacak(hareket);
      bakiye += borc - alacak;
      hareket['_ekstre_borc'] = borc;
      hareket['_ekstre_alacak'] = alacak;
      hareket['_ekstre_bakiye'] = bakiye;
    }
    return liste;
  }

  static Future<Uint8List> pdfOlustur({
    required Map<String, dynamic> cari,
    required List<Map<String, dynamic>> hareketler,
  }) async {
    final firma = await FirmaAyarlariService.getir();
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    final zengin = await belgeBilgileriniTamamla(hareketler);
    final kronolojik = kronolojikHareketler(zengin);
    double toplamBorc = 0;
    double toplamAlacak = 0;
    final satirlar = <List<String>>[];

    for (final hareket in kronolojik) {
      final borc = _sayi(hareket['_ekstre_borc']);
      final alacak = _sayi(hareket['_ekstre_alacak']);
      final bakiye = _sayi(hareket['_ekstre_bakiye']);
      toplamBorc += borc;
      toplamAlacak += alacak;
      satirlar.add([
        tarih(hareket['tarih']),
        islemTuru(hareket),
        faturaNo(hareket),
        hareket['aciklama']?.toString() ?? '-',
        borc == 0 ? '-' : _para(borc),
        alacak == 0 ? '-' : _para(alacak),
        bakiyeMetni(bakiye),
      ]);
    }

    final firmaAdres = [firma.adres, firma.ilce, firma.il]
        .where((e) => e.trim().isNotEmpty)
        .join(' / ');
    final cariAdres = [cari['adres'], cari['ilce'], cari['il']]
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .join(' / ');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 26),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(firma.unvan,
                    style: pw.TextStyle(font: bold, fontSize: 13)),
                if (firmaAdres.isNotEmpty)
                  pw.Text(firmaAdres, style: const pw.TextStyle(fontSize: 7.5)),
                if (firma.telefon.isNotEmpty)
                  pw.Text('Tel: ${firma.telefon}',
                      style: const pw.TextStyle(fontSize: 7.5)),
              ],
            ),
            pw.Text('CARİ HESAP EKSTRESİ',
                style: pw.TextStyle(font: bold, fontSize: 13)),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Sayfa ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 7),
          pw.Divider(),
          pw.Text(cari['unvan']?.toString() ?? '-',
              style: pw.TextStyle(font: bold, fontSize: 11.5)),
          if (cariAdres.isNotEmpty)
            pw.Text('Adres: $cariAdres', style: const pw.TextStyle(fontSize: 8)),
          pw.Row(children: [
            if ((cari['telefon']?.toString().trim() ?? '').isNotEmpty)
              pw.Text('Telefon: ${cari['telefon']}',
                  style: const pw.TextStyle(fontSize: 8)),
            if ((cari['telefon']?.toString().trim() ?? '').isNotEmpty &&
                (cari['vergi_no']?.toString().trim() ?? '').isNotEmpty)
              pw.Text('    •    ', style: const pw.TextStyle(fontSize: 8)),
            if ((cari['vergi_no']?.toString().trim() ?? '').isNotEmpty)
              pw.Text(
                'Vergi: ${cari['vergi_dairesi'] ?? '-'} / ${cari['vergi_no']}',
                style: const pw.TextStyle(fontSize: 8),
              ),
          ]),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: const [
              'Tarih',
              'İşlem Türü',
              'Fatura No',
              'Açıklama',
              'Borç',
              'Alacak',
              'Bakiye',
            ],
            data: satirlar,
            headerStyle: pw.TextStyle(font: bold, fontSize: 7.8),
            cellStyle: const pw.TextStyle(fontSize: 7.1),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.35),
            columnWidths: const {
              0: pw.FixedColumnWidth(72),
              1: pw.FixedColumnWidth(96),
              2: pw.FixedColumnWidth(96),
              3: pw.FlexColumnWidth(3.0),
              4: pw.FixedColumnWidth(78),
              5: pw.FixedColumnWidth(78),
              6: pw.FixedColumnWidth(88),
            },
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Toplam Borç: ${_para(toplamBorc)}',
                  style: pw.TextStyle(font: bold, fontSize: 8.5)),
              pw.SizedBox(width: 18),
              pw.Text('Toplam Alacak: ${_para(toplamAlacak)}',
                  style: pw.TextStyle(font: bold, fontSize: 8.5)),
              pw.SizedBox(width: 18),
              pw.Text(
                'Son Bakiye: ${bakiyeMetni(kronolojik.isEmpty ? 0 : _sayi(kronolojik.last['_ekstre_bakiye']))}',
                style: pw.TextStyle(font: bold, fontSize: 8.5),
              ),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> yazdir({
    required Map<String, dynamic> cari,
    required List<Map<String, dynamic>> hareketler,
  }) async {
    final bytes = await pdfOlustur(cari: cari, hareketler: hareketler);
    await Printing.layoutPdf(
      name: 'Cari Ekstresi ${cari['unvan'] ?? ''}',
      format: PdfPageFormat.a4.landscape,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> paylas({
    required Map<String, dynamic> cari,
    required List<Map<String, dynamic>> hareketler,
  }) async {
    await Printing.sharePdf(
      bytes: await pdfOlustur(cari: cari, hareketler: hareketler),
      filename: 'CARI_EKSTRE_${_dosyaAdi(cari['unvan']?.toString() ?? '')}.pdf',
    );
  }

  static Future<String> excelAktar({
    required Map<String, dynamic> cari,
    required List<Map<String, dynamic>> hareketler,
  }) async {
    final excel = Excel.createExcel();
    final sayfa = excel['CARI EKSTRE'];
    sayfa.appendRow(['Cari', cari['unvan'] ?? '-']);
    sayfa.appendRow(['Telefon', cari['telefon'] ?? '-']);
    sayfa.appendRow([]);
    sayfa.appendRow([
      'Tarih',
      'İşlem Türü',
      'Fatura No',
      'Açıklama',
      'Borç',
      'Alacak',
      'Bakiye',
    ]);

    final zengin = await belgeBilgileriniTamamla(hareketler);
    final kronolojik = kronolojikHareketler(zengin);
    double toplamBorc = 0;
    double toplamAlacak = 0;

    for (final hareket in kronolojik) {
      final borc = _sayi(hareket['_ekstre_borc']);
      final alacak = _sayi(hareket['_ekstre_alacak']);
      final bakiye = _sayi(hareket['_ekstre_bakiye']);
      toplamBorc += borc;
      toplamAlacak += alacak;
      sayfa.appendRow([
        tarih(hareket['tarih']),
        islemTuru(hareket),
        faturaNo(hareket),
        hareket['aciklama'] ?? '-',
        borc,
        alacak,
        bakiyeMetni(bakiye),
      ]);
    }

    sayfa.appendRow([]);
    sayfa.appendRow([
      '',
      '',
      '',
      'TOPLAM',
      toplamBorc,
      toplamAlacak,
      bakiyeMetni(kronolojik.isEmpty ? 0 : _sayi(kronolojik.last['_ekstre_bakiye'])),
    ]);

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Cari ekstre Excel dosyası oluşturulamadı.');
    return ExcelDownload.kaydet(
      dosyaAdi: 'CARI_EKSTRE_${_dosyaAdi(cari['unvan']?.toString() ?? '')}.xlsx',
      bytes: bytes,
    );
  }
}
