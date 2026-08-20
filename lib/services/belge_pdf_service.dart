import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'firma_ayarlari_service.dart';
import 'supabase_service.dart';

class BelgePdfService {
  static double _d(dynamic v) => v is num
      ? v.toDouble()
      : (double.tryParse(v?.toString().replaceAll(',', '.') ?? '0') ?? 0);

  static String _p(dynamic v) => '${_d(v).toStringAsFixed(2)} TL';

  static String _t(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '')?.toLocal();
    return d == null
        ? '-'
        : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  static String _adres(Map<String, dynamic> bilgi) {
    return [bilgi['adres'], bilgi['ilce'], bilgi['il']]
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .join(' / ');
  }

  static String _firmaAdres(FirmaAyarlari firma) {
    return [firma.adres, firma.ilce, firma.il]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' / ');
  }

  static Future<Uint8List> _pdf(
    bool satis,
    int id, {
    required bool ureticiKoduGoster,
  }) async {
    final firma = await FirmaAyarlariService.getir();
    final musteriKopyasi = satis && !ureticiKoduGoster;
    final baslikTablo = satis ? 'satis_baslik' : 'alis_baslik';
    final detayTablo = satis ? 'satis_detay' : 'alis_detay';
    final idKolon = satis ? 'satis_id' : 'alis_id';

    final basliklar = List<Map<String, dynamic>>.from(
      await SupabaseService.supabase
          .from(baslikTablo)
          .select()
          .eq(idKolon, id)
          .limit(1),
    );
    if (basliklar.isEmpty) throw Exception('Fatura bulunamadı.');
    final b = basliklar.first;

    String cariUnvan = '-';
    Map<String, dynamic> cariBilgi = {};
    final cariId = int.tryParse(b['cari_id']?.toString() ?? '');
    if (cariId != null) {
      final cariler = List<Map<String, dynamic>>.from(
        await SupabaseService.supabase
            .from('cariler')
            .select(
              'unvan,adres,il,ilce,telefon,eposta,vergi_dairesi,vergi_no',
            )
            .eq('cari_id', cariId)
            .limit(1),
      );
      if (cariler.isNotEmpty) {
        cariBilgi = cariler.first;
        final u = cariler.first['unvan']?.toString().trim() ?? '';
        if (u.isNotEmpty) cariUnvan = u;
      }
    }

    final detaylar = List<Map<String, dynamic>>.from(
      await SupabaseService.supabase.from(detayTablo).select().eq(idKolon, id),
    );

    final stokIds = detaylar
        .map((x) => int.tryParse(x['stok_id']?.toString() ?? ''))
        .whereType<int>()
        .toSet()
        .toList();

    final stoklar = stokIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await SupabaseService.supabase
                .from('stoklar')
                .select('stok_id,urun_adi,uretici_kodu')
                .inFilter('stok_id', stokIds),
          );

    final stokMap = <int, Map<String, dynamic>>{
      for (final x in stoklar)
        if (int.tryParse(x['stok_id']?.toString() ?? '') != null)
          int.parse(x['stok_id'].toString()): x,
    };

    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    final rows = detaylar.map((x) {
      final sid = int.tryParse(x['stok_id']?.toString() ?? '');
      final stok = sid == null ? null : stokMap[sid];
      final miktar = _d(x['miktar']);
      final fiyat = _d(x['birim_fiyat']);
      final indirim = _d(x['indirim'] ?? x['indirim_orani']);
      final netBirimFiyat = fiyat * (1 - indirim / 100);
      final kdv = _d(x['kdv'] ?? x['kdv_orani']);
      final kayitliToplam = _d(x['toplam_tutar'] ?? x['tutar']);
      final toplam = kayitliToplam != 0
          ? kayitliToplam
          : miktar * fiyat * (1 - indirim / 100) * (1 + kdv / 100);
      return [
        stok?['urun_adi']?.toString() ?? '-',
        if (ureticiKoduGoster)
          stok?['uretici_kodu']?.toString() ?? '-',
        miktar.toStringAsFixed(0),
        _p(musteriKopyasi ? netBirimFiyat : fiyat),
        if (!musteriKopyasi) indirim.toStringAsFixed(2),
        kdv.toStringAsFixed(0),
        _p(toplam),
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  firma.unvan,
                  style: pw.TextStyle(font: bold, fontSize: 16),
                ),
                if (_firmaAdres(firma).isNotEmpty)
                  pw.Text(_firmaAdres(firma),
                      style: const pw.TextStyle(fontSize: 7.5)),
                if (firma.telefon.isNotEmpty || firma.vergiNo.isNotEmpty)
                  pw.Text(
                    [
                      if (firma.telefon.isNotEmpty) 'Tel: ${firma.telefon}',
                      if (firma.vergiNo.isNotEmpty)
                        'Vergi: ${firma.vergiDairesi} / ${firma.vergiNo}',
                    ].join('  •  '),
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  satis ? 'SATIS FATURASI' : 'ALIS FATURASI',
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  satis
                      ? (ureticiKoduGoster
                          ? 'DEPO KOPYASI'
                          : 'MÜŞTERİ KOPYASI')
                      : 'İŞLETME KOPYASI',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 9,
                    color: PdfColors.blueGrey700,
                  ),
                ),
              ],
            ),
          ],
        ),
        footer: (c) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Sayfa ${c.pageNumber}/${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Cari: $cariUnvan'),
                  if (_adres(cariBilgi).isNotEmpty)
                    pw.Text('Adres: ${_adres(cariBilgi)}'),
                  if ((cariBilgi['telefon']?.toString().trim() ?? '').isNotEmpty)
                    pw.Text('Telefon: ${cariBilgi['telefon']}'),
                  if ((cariBilgi['vergi_no']?.toString().trim() ?? '').isNotEmpty)
                    pw.Text(
                      'Vergi: ${cariBilgi['vergi_dairesi'] ?? '-'} / '
                      '${cariBilgi['vergi_no']}',
                    ),
                  pw.Text('Tarih: ${_t(b['tarih'])}'),
                  pw.Text('Odeme: ${b['odeme_tipi'] ?? '-'}'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Fatura No: ${b['fatura_no'] ?? '-'}',
                    style: pw.TextStyle(font: bold),
                  ),
                  pw.Text('Durum: ${b['durum'] ?? '-'}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headers: [
              'Urun',
              if (ureticiKoduGoster) 'Üretici Kodu',
              'Miktar',
              'Birim Fiyat',
              if (!musteriKopyasi) 'Indirim %',
              'KDV %',
              'Toplam',
            ],
            data: rows,
            headerStyle: pw.TextStyle(font: bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Ara Toplam: ${_p(b['toplam_tutar'])}'),
                pw.Text('KDV: ${_p(b['kdv_toplam'])}'),
                pw.Divider(),
                pw.Text(
                  'GENEL TOPLAM: ${_p(b['genel_toplam'] ?? b['toplam_tutar'])}',
                  style: pw.TextStyle(font: bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static Future<void> satisDepoYazdir(int id) async =>
      Printing.layoutPdf(
        name: 'Satış Faturası - Depo Kopyası',
        format: PdfPageFormat.a4,
        onLayout: (_) async => _pdf(
          true,
          id,
          ureticiKoduGoster: true,
        ),
      );

  static Future<void> satisMusteriYazdir(int id) async =>
      Printing.layoutPdf(
        name: 'Satış Faturası - Müşteri Kopyası',
        format: PdfPageFormat.a4,
        onLayout: (_) async => _pdf(
          true,
          id,
          ureticiKoduGoster: false,
        ),
      );

  static Future<void> satisYazdir(int id) =>
      satisDepoYazdir(id);

  static Future<void> alisYazdir(int id) async =>
      Printing.layoutPdf(
        name: 'Alış Faturası',
        format: PdfPageFormat.a4,
        onLayout: (_) async => _pdf(
          false,
          id,
          ureticiKoduGoster: true,
        ),
      );

  static Future<void> satisPaylas(int id) async => Printing.sharePdf(
        bytes: await _pdf(
          true,
          id,
          ureticiKoduGoster: false,
        ),
        filename: 'satis_faturasi_$id.pdf',
      );

  static Future<void> alisPaylas(int id) async => Printing.sharePdf(
        bytes: await _pdf(
          false,
          id,
          ureticiKoduGoster: true,
        ),
        filename: 'alis_faturasi_$id.pdf',
      );

  static Future<Uint8List> satisPdfOlustur(int id) =>
      _pdf(
        true,
        id,
        ureticiKoduGoster: false,
      );

  static Future<Uint8List> alisPdfOlustur(int id) =>
      _pdf(
        false,
        id,
        ureticiKoduGoster: true,
      );

  static Future<Uint8List> _irsaliyePdf(
    bool satis,
    int id, {
    required bool ureticiKoduGoster,
  }) async {
    final firma = await FirmaAyarlariService.getir();
    final musteriKopyasi = satis && !ureticiKoduGoster;
    final baslikTablo =
        satis ? 'satis_irsaliye_baslik' : 'alis_irsaliye_baslik';
    final detayTablo =
        satis ? 'satis_irsaliye_detay' : 'alis_irsaliye_detay';

    final basliklar = List<Map<String, dynamic>>.from(
      await SupabaseService.supabase
          .from(baslikTablo)
          .select()
          .eq('irsaliye_id', id)
          .limit(1),
    );

    if (basliklar.isEmpty) {
      throw Exception('İrsaliye bulunamadı.');
    }

    final b = basliklar.first;

    String cariUnvan = '-';
    Map<String, dynamic> cariBilgi = {};
    final cariId =
        int.tryParse(b['cari_id']?.toString() ?? '');

    if (cariId != null) {
      final cariler =
          List<Map<String, dynamic>>.from(
        await SupabaseService.supabase
            .from('cariler')
            .select(
              'unvan,adres,il,ilce,telefon,eposta,vergi_dairesi,vergi_no',
            )
            .eq('cari_id', cariId)
            .limit(1),
      );

      if (cariler.isNotEmpty) {
        cariBilgi = cariler.first;
        final unvan =
            cariler.first['unvan']?.toString().trim() ?? '';

        if (unvan.isNotEmpty) {
          cariUnvan = unvan;
        }
      }
    }

    String depoAdi = '-';
    final depoId =
        int.tryParse(b['depo_id']?.toString() ?? '');

    if (depoId != null) {
      final depolar =
          List<Map<String, dynamic>>.from(
        await SupabaseService.supabase
            .from('depolar')
            .select('depo_adi')
            .eq('depo_id', depoId)
            .limit(1),
      );

      if (depolar.isNotEmpty) {
        final ad =
            depolar.first['depo_adi']?.toString().trim() ?? '';

        if (ad.isNotEmpty) {
          depoAdi = ad;
        }
      }
    }

    final detaylar =
        List<Map<String, dynamic>>.from(
      await SupabaseService.supabase
          .from(detayTablo)
          .select()
          .eq('irsaliye_id', id)
          .order('detay_id'),
    );

    final stokIds = detaylar
        .map(
          (x) => int.tryParse(
            x['stok_id']?.toString() ?? '',
          ),
        )
        .whereType<int>()
        .toSet()
        .toList();

    final stoklar = stokIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await SupabaseService.supabase
                .from('stoklar')
                .select(
                  'stok_id,urun_adi,uretici_kodu,oem_no,marka,raf',
                )
                .inFilter('stok_id', stokIds),
          );

    final stokMap =
        <int, Map<String, dynamic>>{
      for (final x in stoklar)
        if (int.tryParse(
              x['stok_id']?.toString() ?? '',
            ) !=
            null)
          int.parse(
            x['stok_id'].toString(),
          ): x,
    };

    final regular =
        await PdfGoogleFonts.notoSansRegular();

    final bold =
        await PdfGoogleFonts.notoSansBold();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
      ),
    );

    double araToplam = 0;
    double kdvToplam = 0;
    double genelToplam = 0;

    final rows = detaylar.map((x) {
      final sid =
          int.tryParse(x['stok_id']?.toString() ?? '');

      final stok =
          sid == null ? null : stokMap[sid];

      final miktar =
          _d(x['miktar']);

      final fiyat =
          _d(x['birim_fiyat']);

      final indirim =
          _d(
        x['indirim'] ??
            x['indirim_orani'],
      );

      final netBirimFiyat =
          fiyat * (1 - indirim / 100);

      final kdv =
          _d(
        x['kdv'] ??
            x['kdv_orani'],
      );

      final net =
          miktar *
              fiyat *
              (1 - indirim / 100);

      final kdvTutar =
          net * kdv / 100;

      final toplam =
          net + kdvTutar;

      araToplam += net;
      kdvToplam += kdvTutar;
      genelToplam += toplam;

      return [
        stok?['urun_adi']?.toString() ?? '-',
        if (ureticiKoduGoster)
          stok?['uretici_kodu']?.toString() ?? '-',
        stok?['raf']?.toString() ?? '-',
        miktar.toStringAsFixed(2),
        _p(musteriKopyasi ? netBirimFiyat : fiyat),
        if (!musteriKopyasi) indirim.toStringAsFixed(2),
        kdv.toStringAsFixed(0),
        _p(toplam),
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin:
            const pw.EdgeInsets.all(28),
        header: (_) => pw.Row(
          mainAxisAlignment:
              pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  firma.unvan,
                  style: pw.TextStyle(font: bold, fontSize: 16),
                ),
                if (_firmaAdres(firma).isNotEmpty)
                  pw.Text(
                    _firmaAdres(firma),
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
                if (firma.telefon.isNotEmpty || firma.vergiNo.isNotEmpty)
                  pw.Text(
                    [
                      if (firma.telefon.isNotEmpty) 'Tel: ${firma.telefon}',
                      if (firma.vergiNo.isNotEmpty)
                        'Vergi: ${firma.vergiDairesi} / ${firma.vergiNo}',
                    ].join('  •  '),
                    style: const pw.TextStyle(fontSize: 7.5),
                  ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  satis
                      ? 'SATIS IRSALIYESI'
                      : 'ALIS IRSALIYESI',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 14,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  satis
                      ? (ureticiKoduGoster
                          ? 'DEPO KOPYASI'
                          : 'MÜŞTERİ KOPYASI')
                      : 'İŞLETME KOPYASI',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 9,
                    color: PdfColors.blueGrey700,
                  ),
                ),
              ],
            ),
          ],
        ),
        footer: (c) => pw.Align(
          alignment:
              pw.Alignment.centerRight,
          child: pw.Text(
            'Sayfa ${c.pageNumber}/${c.pagesCount}',
            style:
                const pw.TextStyle(
              fontSize: 8,
            ),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${satis ? 'Müşteri' : 'Tedarikçi'}: $cariUnvan',
                  ),
                  if (_adres(cariBilgi).isNotEmpty)
                    pw.Text('Adres: ${_adres(cariBilgi)}'),
                  if ((cariBilgi['telefon']?.toString().trim() ?? '').isNotEmpty)
                    pw.Text('Telefon: ${cariBilgi['telefon']}'),
                  if ((cariBilgi['vergi_no']?.toString().trim() ?? '').isNotEmpty)
                    pw.Text(
                      'Vergi: ${cariBilgi['vergi_dairesi'] ?? '-'} / '
                      '${cariBilgi['vergi_no']}',
                    ),
                  pw.Text(
                    'Tarih: ${_t(b['tarih'])}',
                  ),
                  pw.Text(
                    'Depo: $depoAdi',
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'İrsaliye No: ${b['irsaliye_no'] ?? '-'}',
                    style:
                        pw.TextStyle(
                      font: bold,
                    ),
                  ),
                  pw.Text(
                    'Durum: ${b['durum'] ?? '-'}',
                  ),
                  pw.Text(
                    'Kullanıcı: ${b['kullanici'] ?? '-'}',
                  ),
                ],
              ),
            ],
          ),
          if ((b['aciklama']
                      ?.toString()
                      .trim() ??
                  '')
              .isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Açıklama: ${b['aciklama']}',
              style:
                  const pw.TextStyle(
                fontSize: 9,
              ),
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headers: [
              'Ürün',
              if (ureticiKoduGoster) 'Üretici Kodu',
              'RAF',
              'Miktar',
              'Birim Fiyat',
              if (!musteriKopyasi) 'İndirim %',
              'KDV %',
              'Toplam',
            ],
            data: rows,
            headerStyle:
                pw.TextStyle(
              font: bold,
              fontSize: 7.5,
            ),
            cellStyle:
                const pw.TextStyle(
              fontSize: 7,
            ),
            headerDecoration:
                const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment:
                pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Ara Toplam: ${_p(araToplam)}',
                ),
                pw.Text(
                  'KDV: ${_p(kdvToplam)}',
                ),
                pw.Divider(),
                pw.Text(
                  'GENEL TOPLAM: ${_p(genelToplam)}',
                  style:
                      pw.TextStyle(
                    font: bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Container(
                width: 180,
                height: 65,
                decoration:
                    pw.BoxDecoration(
                  border: pw.Border.all(
                    color:
                        PdfColors.grey400,
                  ),
                ),
                padding:
                    const pw.EdgeInsets.all(6),
                child: pw.Text(
                  satis
                      ? 'Teslim Eden'
                      : 'Teslim Alan',
                  style:
                      const pw.TextStyle(
                    fontSize: 8,
                  ),
                ),
              ),
              pw.Container(
                width: 180,
                height: 65,
                decoration:
                    pw.BoxDecoration(
                  border: pw.Border.all(
                    color:
                        PdfColors.grey400,
                  ),
                ),
                padding:
                    const pw.EdgeInsets.all(6),
                child: pw.Text(
                  satis
                      ? 'Teslim Alan'
                      : 'Teslim Eden',
                  style:
                      const pw.TextStyle(
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static Future<void> satisIrsaliyeYazdir(
    int id,
  ) =>
      satisIrsaliyeDepoYazdir(id);

  static Future<void> satisIrsaliyeDepoYazdir(
    int id,
  ) async =>
      Printing.layoutPdf(
        name: 'Satış İrsaliyesi - Depo Kopyası',
        format: PdfPageFormat.a4,
        onLayout: (_) async =>
            _irsaliyePdf(
          true,
          id,
          ureticiKoduGoster: true,
        ),
      );

  static Future<void> satisIrsaliyeMusteriYazdir(
    int id,
  ) async =>
      Printing.layoutPdf(
        name: 'Satış İrsaliyesi - Müşteri Kopyası',
        format: PdfPageFormat.a4,
        onLayout: (_) async =>
            _irsaliyePdf(
          true,
          id,
          ureticiKoduGoster: false,
        ),
      );

  static Future<void> alisIrsaliyeYazdir(
    int id,
  ) async =>
      Printing.layoutPdf(
        name: 'Alış İrsaliyesi',
        format: PdfPageFormat.a4,
        onLayout: (_) async =>
            _irsaliyePdf(
          false,
          id,
          ureticiKoduGoster: true,
        ),
      );

  static Future<void> satisIrsaliyePaylas(
    int id,
  ) async =>
      Printing.sharePdf(
        bytes:
            await _irsaliyePdf(
          true,
          id,
          ureticiKoduGoster: false,
        ),
        filename:
            'satis_irsaliyesi_$id.pdf',
      );

  static Future<void> alisIrsaliyePaylas(
    int id,
  ) async =>
      Printing.sharePdf(
        bytes:
            await _irsaliyePdf(
          false,
          id,
          ureticiKoduGoster: true,
        ),
        filename:
            'alis_irsaliyesi_$id.pdf',
      );

  static Future<Uint8List> satisIrsaliyePdfOlustur(int id) =>
      _irsaliyePdf(
        true,
        id,
        ureticiKoduGoster: false,
      );

  static Future<Uint8List> alisIrsaliyePdfOlustur(int id) =>
      _irsaliyePdf(
        false,
        id,
        ureticiKoduGoster: true,
      );

}
