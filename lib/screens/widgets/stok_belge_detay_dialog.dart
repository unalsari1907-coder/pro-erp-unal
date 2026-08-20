import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import '../../widgets/mobil_uyum.dart';

class StokBelgeDetayDialog {
  static String _metin(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  static double _sayi(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '0') ??
        0.0;
  }

  static String _para(dynamic value) {
    return '${_sayi(value).toStringAsFixed(2)} ₺';
  }

  static String _tarih(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '-';

    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw;

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  static Widget _mobilKalemKarti(
    Map<String, dynamic> detay,
    MaterialColor renk,
  ) {
    final miktar = _sayi(detay['miktar']);
    final fiyat = _sayi(detay['birim_fiyat']);
    final indirim = _sayi(detay['indirim'] ?? detay['indirim_orani']);
    final kdv = _sayi(detay['kdv'] ?? detay['kdv_orani']);
    final matrah = miktar * fiyat * (1 - indirim / 100);
    final hesaplanan = matrah * (1 + kdv / 100);
    final kayitli = _sayi(detay['tutar'] ?? detay['toplam']);
    final toplam = kayitli > 0 ? kayitli : hesaplanan;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _metin(detay['urun_adi']),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'ÜRETİCİ KODU: ${_metin(detay['uretici_kodu'])}',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text('OEM: ${_metin(detay['oem_no'])}'),
            Text('Marka: ${_metin(detay['marka'])}'),
            Text('RAF: ${_metin(detay['raf'])}'),
            const Divider(height: 18),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Text('Miktar: ${miktar.toStringAsFixed(2)}'),
                Text('Birim: ${_para(fiyat)}'),
                Text('İndirim: %${indirim.toStringAsFixed(2)}'),
                Text('KDV: %${kdv.toStringAsFixed(0)}'),
                Text(
                  'Toplam: ${_para(toplam)}',
                  style: TextStyle(
                    color: renk.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static bool _alisMi(String islem) {
    final normalized = islem.toUpperCase();

    return normalized == 'ALIS' ||
        normalized == 'ALIŞ' ||
        normalized.startsWith('ALIS_') ||
        normalized.startsWith('ALIŞ_');
  }

  static bool _satisMi(String islem) {
    final normalized = islem.toUpperCase();

    return normalized == 'SATIS' ||
        normalized == 'SATIŞ' ||
        normalized.startsWith('SATIS_') ||
        normalized.startsWith('SATIŞ_');
  }

  static bool _irsaliyeMi(String islem) {
    final normalized = islem.toUpperCase();

    return normalized.contains('IRSALIYE') || normalized.contains('İRSALİYE');
  }

  static Future<void> _belgeNumaralariniTamamla(
    Map<String, dynamic> hareket,
  ) async {
    final islem = _metin(hareket['islem_tipi']).toUpperCase();
    final alisMi = _alisMi(islem);
    final satisMi = _satisMi(islem);

    if (!alisMi && !satisMi) return;

    final irsaliyeHareketi = _irsaliyeMi(islem);
    final faturaTablo = alisMi ? 'alis_baslik' : 'satis_baslik';
    final faturaIdKolonu = alisMi ? 'alis_id' : 'satis_id';
    final irsaliyeTablo = alisMi
        ? 'alis_irsaliye_baslik'
        : 'satis_irsaliye_baslik';
    final baglantiTablo = alisMi
        ? 'alis_irsaliye_fatura'
        : 'satis_irsaliye_fatura';

    String faturaNo = hareket['fatura_no']?.toString().trim() ?? '';
    String irsaliyeNo = hareket['irsaliye_no']?.toString().trim() ?? '';
    final belgeNo = hareket['belge_no']?.toString().trim() ?? '';

    if (irsaliyeHareketi && irsaliyeNo.isEmpty && belgeNo.isNotEmpty) {
      irsaliyeNo = belgeNo;
    }

    try {
      if (!irsaliyeHareketi) {
        int? faturaId = int.tryParse(
          hareket[alisMi ? 'alis_ref' : 'satis_ref']?.toString() ?? '',
        );

        Map<String, dynamic>? fatura;

        if (faturaId != null && faturaId > 0) {
          final response = await SupabaseService.supabase
              .from(faturaTablo)
              .select('$faturaIdKolonu, fatura_no${alisMi ? '' : ', belge_no'}')
              .eq(faturaIdKolonu, faturaId)
              .limit(1);
          final list = List<Map<String, dynamic>>.from(response);
          if (list.isNotEmpty) fatura = list.first;
        }

        if (fatura == null && faturaNo.isNotEmpty && faturaNo != '-') {
          final response = await SupabaseService.supabase
              .from(faturaTablo)
              .select('$faturaIdKolonu, fatura_no${alisMi ? '' : ', belge_no'}')
              .eq('fatura_no', faturaNo)
              .limit(1);
          final list = List<Map<String, dynamic>>.from(response);
          if (list.isNotEmpty) fatura = list.first;
        }

        if (fatura == null && belgeNo.isNotEmpty && belgeNo != '-') {
          final response = await SupabaseService.supabase
              .from(faturaTablo)
              .select('$faturaIdKolonu, fatura_no${alisMi ? '' : ', belge_no'}')
              .eq('fatura_no', belgeNo)
              .limit(1);
          final list = List<Map<String, dynamic>>.from(response);
          if (list.isNotEmpty) fatura = list.first;
        }

        if (fatura == null && !alisMi && belgeNo.isNotEmpty && belgeNo != '-') {
          final response = await SupabaseService.supabase
              .from(faturaTablo)
              .select('$faturaIdKolonu, fatura_no, belge_no')
              .eq('belge_no', belgeNo)
              .limit(1);
          final list = List<Map<String, dynamic>>.from(response);
          if (list.isNotEmpty) fatura = list.first;
        }

        if (fatura != null) {
          faturaId = int.tryParse(fatura[faturaIdKolonu]?.toString() ?? '');
          final bulunanFaturaNo = fatura['fatura_no']?.toString().trim() ?? '';
          if (bulunanFaturaNo.isNotEmpty) faturaNo = bulunanFaturaNo;
        }

        if (faturaId != null && faturaId > 0) {
          final baglantilar = await SupabaseService.supabase
              .from(baglantiTablo)
              .select('irsaliye_id')
              .eq(faturaIdKolonu, faturaId);

          final ids = List<Map<String, dynamic>>.from(baglantilar)
              .map((e) => int.tryParse(e['irsaliye_id']?.toString() ?? ''))
              .whereType<int>()
              .toSet()
              .toList();

          if (ids.isNotEmpty) {
            final response = await SupabaseService.supabase
                .from(irsaliyeTablo)
                .select('irsaliye_id, irsaliye_no')
                .inFilter('irsaliye_id', ids)
                .order('irsaliye_id');
            final nolar = List<Map<String, dynamic>>.from(response)
                .map((e) => e['irsaliye_no']?.toString().trim() ?? '')
                .where((e) => e.isNotEmpty)
                .toList();
            if (nolar.isNotEmpty) irsaliyeNo = nolar.join(', ');
          }
        }
      } else {
        int? irsaliyeId;
        if (irsaliyeNo.isNotEmpty && irsaliyeNo != '-') {
          final response = await SupabaseService.supabase
              .from(irsaliyeTablo)
              .select('irsaliye_id, irsaliye_no')
              .eq('irsaliye_no', irsaliyeNo)
              .limit(1);
          final list = List<Map<String, dynamic>>.from(response);
          if (list.isNotEmpty) {
            irsaliyeId = int.tryParse(
              list.first['irsaliye_id']?.toString() ?? '',
            );
          }
        }

        if (irsaliyeId != null) {
          final baglantilar = await SupabaseService.supabase
              .from(baglantiTablo)
              .select(faturaIdKolonu)
              .eq('irsaliye_id', irsaliyeId);

          final ids = List<Map<String, dynamic>>.from(baglantilar)
              .map((e) => int.tryParse(e[faturaIdKolonu]?.toString() ?? ''))
              .whereType<int>()
              .toSet()
              .toList();

          if (ids.isNotEmpty) {
            final response = await SupabaseService.supabase
                .from(faturaTablo)
                .select('$faturaIdKolonu, fatura_no')
                .inFilter(faturaIdKolonu, ids)
                .order(faturaIdKolonu);
            final nolar = List<Map<String, dynamic>>.from(response)
                .map((e) => e['fatura_no']?.toString().trim() ?? '')
                .where((e) => e.isNotEmpty)
                .toList();
            if (nolar.isNotEmpty) faturaNo = nolar.join(', ');
          }
        }
      }
    } catch (_) {
      // Bağlantı tablosu veya eski kayıt eksikse mevcut numaralar gösterilir.
    }

    hareket['fatura_no'] = faturaNo.isEmpty ? '-' : faturaNo;
    hareket['irsaliye_no'] = irsaliyeNo.isEmpty ? '-' : irsaliyeNo;
  }

  static Future<void> ac(
    BuildContext context,
    Map<String, dynamic> hareket,
  ) async {
    final detayHareket = Map<String, dynamic>.from(hareket);
    await _belgeNumaralariniTamamla(detayHareket);

    final islem = _metin(detayHareket['islem_tipi']).toUpperCase();

    if (!_alisMi(islem) && !_satisMi(islem)) {
      await _genelHareketGoster(context, detayHareket);
      return;
    }

    if (_irsaliyeMi(islem)) {
      await _irsaliyeGoster(context, detayHareket, alisMi: _alisMi(islem));
      return;
    }

    await _faturaGoster(context, detayHareket, alisMi: _alisMi(islem));
  }

  static Future<Map<String, dynamic>?> _faturaBul(
    Map<String, dynamic> hareket, {
    required bool alisMi,
  }) async {
    final tablo = alisMi ? 'alis_baslik' : 'satis_baslik';

    final idKolonu = alisMi ? 'alis_id' : 'satis_id';

    final ref = int.tryParse(
      hareket[alisMi ? 'alis_ref' : 'satis_ref']?.toString() ?? '',
    );

    if (ref != null && ref > 0) {
      final response = await SupabaseService.supabase
          .from(tablo)
          .select()
          .eq(idKolonu, ref)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(response);

      if (list.isNotEmpty) {
        return list.first;
      }
    }

    final faturaNo = hareket['fatura_no']?.toString().trim() ?? '';

    final belgeNo = hareket['belge_no']?.toString().trim() ?? '';

    final cariId = int.tryParse(hareket['cari_id']?.toString() ?? '');

    if (faturaNo.isNotEmpty && faturaNo != '-') {
      final response = await SupabaseService.supabase
          .from(tablo)
          .select()
          .eq('fatura_no', faturaNo)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(response);

      if (list.isNotEmpty) {
        return list.first;
      }
    }

    if (belgeNo.isNotEmpty && belgeNo != '-') {
      final response = await SupabaseService.supabase
          .from(tablo)
          .select()
          .eq('fatura_no', belgeNo)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(response);

      if (list.isNotEmpty) {
        return list.first;
      }
    }

    if (!alisMi && belgeNo.isNotEmpty && belgeNo != '-') {
      final response = await SupabaseService.supabase
          .from(tablo)
          .select()
          .eq('belge_no', belgeNo)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(response);

      if (list.isNotEmpty) {
        return list.first;
      }
    }

    if (cariId == null) {
      return null;
    }

    final response = await SupabaseService.supabase
        .from(tablo)
        .select()
        .eq('cari_id', cariId)
        .order('tarih', ascending: false)
        .limit(50);

    final faturalar = List<Map<String, dynamic>>.from(response);

    if (faturalar.isEmpty) {
      return null;
    }

    final hareketTarihi = DateTime.tryParse(hareket['tarih']?.toString() ?? '')
        ?.toLocal();

    final stokId = int.tryParse(hareket['stok_id']?.toString() ?? '');

    Map<String, dynamic>? enIyi;
    double enIyiPuan = double.infinity;

    for (final fatura in faturalar) {
      final faturaTarihi = DateTime.tryParse(fatura['tarih']?.toString() ?? '')
          ?.toLocal();

      double puan = 0;

      if (hareketTarihi != null && faturaTarihi != null) {
        puan += hareketTarihi
            .difference(faturaTarihi)
            .inSeconds
            .abs()
            .toDouble();
      } else {
        puan += 1000000;
      }

      if (stokId != null) {
        try {
          final id = int.tryParse(fatura[idKolonu]?.toString() ?? '');

          if (id != null) {
            final detayResponse = await SupabaseService.supabase
                .from(alisMi ? 'alis_detay' : 'satis_detay')
                .select('stok_id')
                .eq(idKolonu, id)
                .eq('stok_id', stokId)
                .limit(1);

            final detayList = List<Map<String, dynamic>>.from(detayResponse);

            if (detayList.isEmpty) {
              puan += 500000;
            }
          }
        } catch (e) {
          debugPrint('PRO ERP sessiz hata [$e]');
        }
      }

      if (puan < enIyiPuan) {
        enIyiPuan = puan;
        enIyi = fatura;
      }
    }

    return enIyi;
  }

  static Future<void> _faturaGoster(
    BuildContext context,
    Map<String, dynamic> hareket, {
    required bool alisMi,
  }) async {
    final fatura = await _faturaBul(hareket, alisMi: alisMi);

    if (!context.mounted) return;

    if (fatura == null) {
      await _genelHareketGoster(
        context,
        hareket,
        mesaj: 'İlgili ${alisMi ? 'alış' : 'satış'} faturası bulunamadı.',
      );
      return;
    }

    final idKolonu = alisMi ? 'alis_id' : 'satis_id';

    final id = int.tryParse(fatura[idKolonu]?.toString() ?? '');

    if (id == null) {
      return;
    }

    final detayResponse = await SupabaseService.supabase
        .from(alisMi ? 'alis_detay' : 'satis_detay')
        .select()
        .eq(idKolonu, id);

    final detaylar = List<Map<String, dynamic>>.from(detayResponse);

    await _stokBilgileriniEkle(detaylar);

    if (!context.mounted) return;

    await _belgeDialog(
      context,
      baslik:
          '${alisMi ? 'Alış' : 'Satış'} Faturası: '
          '${_metin(fatura['fatura_no'])}',
      altBaslik: alisMi
          ? 'Bu cariden hangi ürünün hangi fiyattan alındığı'
          : 'Bu cariye hangi ürünün hangi fiyattan çıktığı',
      hareket: hareket,
      belge: fatura,
      detaylar: detaylar,
      alisMi: alisMi,
      irsaliyeMi: false,
    );
  }

  static Future<void> _irsaliyeGoster(
    BuildContext context,
    Map<String, dynamic> hareket, {
    required bool alisMi,
  }) async {
    final baslikTablo = alisMi
        ? 'alis_irsaliye_baslik'
        : 'satis_irsaliye_baslik';

    final detayTablo = alisMi ? 'alis_irsaliye_detay' : 'satis_irsaliye_detay';

    final belgeNo = hareket['belge_no']?.toString().trim() ?? '';

    final faturaNo = hareket['fatura_no']?.toString().trim() ?? '';

    Map<String, dynamic>? baslik;

    if (belgeNo.isNotEmpty && belgeNo != '-') {
      final response = await SupabaseService.supabase
          .from(baslikTablo)
          .select()
          .eq('irsaliye_no', belgeNo)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(response);

      if (list.isNotEmpty) {
        baslik = list.first;
      }
    }

    if (baslik == null && faturaNo.isNotEmpty && faturaNo != '-') {
      try {
        final response = await SupabaseService.supabase
            .from(baslikTablo)
            .select()
            .eq('irsaliye_no', faturaNo)
            .limit(1);

        final list = List<Map<String, dynamic>>.from(response);

        if (list.isNotEmpty) {
          baslik = list.first;
        }
      } catch (e) {
        debugPrint('PRO ERP sessiz hata [$e]');
      }
    }

    if (!context.mounted) return;

    if (baslik == null) {
      await _genelHareketGoster(
        context,
        hareket,
        mesaj: 'İlgili ${alisMi ? 'alış' : 'satış'} irsaliyesi bulunamadı.',
      );
      return;
    }

    final irsaliyeId = int.tryParse(baslik['irsaliye_id']?.toString() ?? '');

    if (irsaliyeId == null) return;

    final detayResponse = await SupabaseService.supabase
        .from(detayTablo)
        .select()
        .eq('irsaliye_id', irsaliyeId);

    final detaylar = List<Map<String, dynamic>>.from(detayResponse);

    await _stokBilgileriniEkle(detaylar);

    if (!context.mounted) return;

    await _belgeDialog(
      context,
      baslik:
          '${alisMi ? 'Alış' : 'Satış'} İrsaliyesi: '
          '${_metin(baslik['irsaliye_no'])}',
      altBaslik: 'İrsaliye kalemleri ve fiyatları',
      hareket: hareket,
      belge: baslik,
      detaylar: detaylar,
      alisMi: alisMi,
      irsaliyeMi: true,
    );
  }

  static Future<void> _stokBilgileriniEkle(
    List<Map<String, dynamic>> detaylar,
  ) async {
    final stokIds = detaylar
        .map((d) => int.tryParse(d['stok_id']?.toString() ?? ''))
        .whereType<int>()
        .toSet()
        .toList();

    if (stokIds.isEmpty) return;

    final response = await SupabaseService.supabase
        .from('stoklar')
        .select(
          'stok_id, urun_adi, uretici_kodu, '
          'oem_no, marka, raf',
        )
        .inFilter('stok_id', stokIds);

    final stoklar = List<Map<String, dynamic>>.from(response);

    final map = <int, Map<String, dynamic>>{
      for (final stok in stoklar)
        if (int.tryParse(stok['stok_id']?.toString() ?? '') != null)
          int.parse(stok['stok_id'].toString()): stok,
    };

    for (final detay in detaylar) {
      final stokId = int.tryParse(detay['stok_id']?.toString() ?? '');

      final stok = stokId == null ? null : map[stokId];

      detay['urun_adi'] = stok?['urun_adi'] ?? '-';
      detay['uretici_kodu'] = stok?['uretici_kodu'] ?? '-';
      detay['oem_no'] = stok?['oem_no'] ?? '-';
      detay['marka'] = stok?['marka'] ?? '-';
      detay['raf'] = stok?['raf'] ?? '-';
    }
  }

  static Future<void> _belgeDialog(
    BuildContext context, {
    required String baslik,
    required String altBaslik,
    required Map<String, dynamic> hareket,
    required Map<String, dynamic> belge,
    required List<Map<String, dynamic>> detaylar,
    required bool alisMi,
    required bool irsaliyeMi,
  }) async {
    final renk = alisMi ? Colors.teal : Colors.blue;

    final toplamTutar = _sayi(belge['toplam_tutar'] ?? belge['ara_toplam']);

    final kdvToplam = _sayi(belge['kdv_toplam']);

    final genelToplam = _sayi(
      belge['genel_toplam'] ?? (toplamTutar + kdvToplam),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final mobil = MobilUyum.telefon(dialogContext);

        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          title: Row(
            children: [
              Icon(
                irsaliyeMi
                    ? Icons.local_shipping_rounded
                    : (alisMi ? Icons.shopping_cart : Icons.receipt_long),
                color: renk.shade700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(baslik),
                    Text(
                      altBaslik,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: MobilDialogIcerik(
            width: 1120,
            height: 680,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Wrap(
                    spacing: 34,
                    runSpacing: 12,
                    children: [
                      _bilgi('Cari', _metin(hareket['cari_unvan'])),
                      _bilgi(
                        'İrsaliye No',
                        _metin(hareket['irsaliye_no'] ?? belge['irsaliye_no']),
                      ),
                      _bilgi(
                        'Fatura No',
                        _metin(hareket['fatura_no'] ?? belge['fatura_no']),
                      ),
                      _bilgi(
                        'Tarih',
                        _tarih(belge['tarih'] ?? hareket['tarih']),
                      ),
                      _bilgi('Depo', _metin(hareket['depo_adi'])),
                      if (!irsaliyeMi)
                        _bilgi('Ödeme Tipi', _metin(belge['odeme_tipi'])),
                      _bilgi('Durum', _metin(belge['durum'])),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: detaylar.isEmpty
                      ? const Center(child: Text('Belge kalemi bulunamadı.'))
                      : mobil
                      ? ListView.separated(
                          itemCount: detaylar.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _mobilKalemKarti(detaylar[index], renk),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: SizedBox(
                                width: constraints.maxWidth,
                                child: MobilTablo(
                                  child: DataTable(
                                    columnSpacing: 22,
                                    horizontalMargin: 12,
                                    dataRowMinHeight: 58,
                                    dataRowMaxHeight: 76,
                                    columns: const [
                                      DataColumn(label: Text('Ürün')),
                                      DataColumn(label: Text('Kod')),
                                      DataColumn(label: Text('RAF')),
                                      DataColumn(
                                        numeric: true,
                                        label: Text('Miktar'),
                                      ),
                                      DataColumn(
                                        numeric: true,
                                        label: Text('Birim Fiyat'),
                                      ),
                                      DataColumn(
                                        numeric: true,
                                        label: Text('İndirim %'),
                                      ),
                                      DataColumn(
                                        numeric: true,
                                        label: Text('KDV %'),
                                      ),
                                      DataColumn(
                                        numeric: true,
                                        label: Text('Toplam'),
                                      ),
                                    ],
                                    rows: detaylar.map((detay) {
                                      final miktar = _sayi(detay['miktar']);

                                      final fiyat = _sayi(detay['birim_fiyat']);

                                      final indirim = _sayi(
                                        detay['indirim'] ??
                                            detay['indirim_orani'],
                                      );

                                      final kdv = _sayi(
                                        detay['kdv'] ?? detay['kdv_orani'],
                                      );

                                      final matrah =
                                          miktar * fiyat * (1 - indirim / 100);

                                      final hesaplanan =
                                          matrah * (1 + kdv / 100);

                                      final kayitli = _sayi(
                                        detay['tutar'] ?? detay['toplam'],
                                      );

                                      final satirToplam = kayitli > 0
                                          ? kayitli
                                          : hesaplanan;

                                      final hareketStokId = int.tryParse(
                                        hareket['stok_id']?.toString() ?? '',
                                      );

                                      final detayStokId = int.tryParse(
                                        detay['stok_id']?.toString() ?? '',
                                      );

                                      final incelenenUrunMu =
                                          hareketStokId != null &&
                                          detayStokId != null &&
                                          hareketStokId == detayStokId;

                                      return DataRow(
                                        color: incelenenUrunMu
                                            ? MaterialStatePropertyAll<Color?>(
                                                renk.withOpacity(0.12),
                                              )
                                            : null,
                                        cells: [
                                          DataCell(
                                            SizedBox(
                                              width: 360,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _metin(detay['urun_adi']),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'OEM: ${_metin(detay['oem_no'])}'
                                                    ' • ${_metin(detay['marka'])}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(_metin(detay['uretici_kodu'])),
                                          ),
                                          DataCell(Text(_metin(detay['raf']))),
                                          DataCell(
                                            Text(
                                              miktar.toStringAsFixed(
                                                miktar == miktar.roundToDouble()
                                                    ? 0
                                                    : 2,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              _para(fiyat),
                                              style: TextStyle(
                                                color: renk.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(indirim.toStringAsFixed(2)),
                                          ),
                                          DataCell(
                                            Text(kdv.toStringAsFixed(0)),
                                          ),
                                          DataCell(
                                            Text(
                                              _para(satirToplam),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const Divider(height: 18),
                if (!irsaliyeMi || genelToplam > 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 12,
                      children: [
                        _toplam('Ara Toplam', _para(toplamTutar)),
                        _toplam('KDV', _para(kdvToplam)),
                        _toplam(
                          'Genel Toplam',
                          _para(genelToplam),
                          vurgu: true,
                          renk: renk,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  static Widget _bilgi(String baslik, String deger) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(deger, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static Widget _toplam(
    String baslik,
    String deger, {
    bool vurgu = false,
    MaterialColor renk = Colors.blue,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: vurgu ? renk.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: vurgu ? renk.shade100 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            baslik,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            deger,
            style: TextStyle(
              fontSize: vurgu ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: vurgu ? renk.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _genelHareketGoster(
    BuildContext context,
    Map<String, dynamic> hareket, {
    String? mesaj,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Stok Hareket Detayı'),
          content: MobilDialogIcerik(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mesaj != null) ...[
                  Text(
                    mesaj,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Divider(height: 24),
                ],
                _satir('Ürün', _metin(hareket['urun_adi'])),
                _satir('İşlem', _metin(hareket['islem_tipi'])),
                _satir('Miktar', _metin(hareket['miktar'])),
                _satir('Fatura No', _metin(hareket['fatura_no'])),
                _satir(
                  'İrsaliye No',
                  _metin(hareket['irsaliye_no'] ?? hareket['belge_no']),
                ),
                _satir('Cari', _metin(hareket['cari_unvan'])),
                _satir('Depo', _metin(hareket['depo_adi'])),
                _satir('Tarih', _tarih(hareket['tarih'])),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  static Widget _satir(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(baslik, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(deger)),
        ],
      ),
    );
  }
}
