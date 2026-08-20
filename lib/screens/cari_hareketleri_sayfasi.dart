// lib/screens/cari_hareketleri_sayfasi.dart

import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import '../services/supabase_service.dart';

class CariHareketleriSayfasi extends StatefulWidget {
  const CariHareketleriSayfasi({super.key});

  @override
  State<CariHareketleriSayfasi> createState() => _CariHareketleriSayfasiState();
}

class _CariHareketleriSayfasiState extends State<CariHareketleriSayfasi> {
  final TextEditingController _aramaController = TextEditingController();

  bool _yukleniyor = true;

  String _islemFiltresi = 'TÜMÜ';
  int? _secilenCariId;

  List<Map<String, dynamic>> _cariler = [];
  List<Map<String, dynamic>> _tumHareketler = [];
  List<Map<String, dynamic>> _gorunenHareketler = [];

  @override
  void initState() {
    super.initState();
    _aramaController.addListener(_filtrele);
    _verileriYukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    if (!mounted) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from('cari_hareket')
            .select(
              'hareket_id, tarih, cari_id, islem_tipi, belge_no, '
              'borc, alacak, aciklama, kullanici',
            )
            .order('tarih', ascending: false),
        SupabaseService.supabase
            .from('cariler')
            .select('cari_id, unvan, cari_tipi, bakiye, aktif')
            .order('unvan'),
      ]);

      final hareketler = List<Map<String, dynamic>>.from(sonuclar[0] as List);

      final cariler = List<Map<String, dynamic>>.from(sonuclar[1] as List);

      final cariHaritasi = <int, Map<String, dynamic>>{};

      for (final cari in cariler) {
        final cariId = int.tryParse(cari['cari_id']?.toString() ?? '');

        if (cariId != null) {
          cariHaritasi[cariId] = cari;
        }
      }

      for (final hareket in hareketler) {
        final cariId = int.tryParse(hareket['cari_id']?.toString() ?? '');

        final cari = cariId == null ? null : cariHaritasi[cariId];

        hareket['cari_unvan'] = cari?['unvan']?.toString() ?? '-';

        hareket['cari_tipi'] = cari?['cari_tipi']?.toString() ?? '-';

        hareket['cari_bakiye'] = cari?['bakiye'] ?? 0;
      }

      if (!mounted) return;

      setState(() {
        _cariler = cariler;
        _tumHareketler = hareketler;
        _gorunenHareketler = hareketler;
        _yukleniyor = false;
      });

      _filtrele();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      _mesaj('Cari hareketleri yüklenemedi: $e', Colors.red);
    }
  }

  void _filtrele() {
    final kelimeler = _aramaController.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((kelime) => kelime.isNotEmpty)
        .toList();

    if (!mounted) return;

    setState(() {
      _gorunenHareketler = _tumHareketler.where((hareket) {
        final cariId = int.tryParse(hareket['cari_id']?.toString() ?? '');

        if (_secilenCariId != null && cariId != _secilenCariId) {
          return false;
        }

        final islemTipi = _metin(hareket['islem_tipi']).toUpperCase();

        final filtreUyuyor =
            _islemFiltresi == 'TÜMÜ' ||
            (_islemFiltresi == 'SATIŞ' &&
                (islemTipi == 'SATIS' || islemTipi == 'SATIŞ')) ||
            (_islemFiltresi == 'ALIŞ' &&
                (islemTipi == 'ALIS' || islemTipi == 'ALIŞ')) ||
            (_islemFiltresi == 'TAHSİLAT' &&
                (islemTipi.contains('TAHSILAT') ||
                    islemTipi.contains('TAHSİLAT'))) ||
            (_islemFiltresi == 'ÖDEME' &&
                (islemTipi.contains('ODEME') || islemTipi.contains('ÖDEME'))) ||
            (_islemFiltresi == 'İPTAL' &&
                (islemTipi.contains('IPTAL') || islemTipi.contains('İPTAL')));

        if (!filtreUyuyor) return false;

        if (kelimeler.isEmpty) return true;

        final metin = [
          hareket['hareket_id'],
          hareket['cari_unvan'],
          hareket['cari_tipi'],
          hareket['islem_tipi'],
          hareket['belge_no'],
          hareket['aciklama'],
          hareket['kullanici'],
        ].map((deger) => deger?.toString() ?? '').join(' ').toLowerCase();

        return kelimeler.every(metin.contains);
      }).toList();
    });
  }

  String _metin(dynamic deger) {
    final sonuc = deger?.toString().trim() ?? '';
    return sonuc.isEmpty ? '-' : sonuc;
  }

  double _sayi(dynamic deger) {
    return double.tryParse(deger?.toString().replaceAll(',', '.') ?? '0') ??
        0.0;
  }

  String _para(dynamic deger) {
    return '${_sayi(deger).toStringAsFixed(2)} ₺';
  }

  double _gosterimBorc(Map<String, dynamic> hareket) {
    final tip = _metin(hareket['islem_tipi']).toUpperCase();
    if (tip == 'VIRMAN_TEDARIKCI' || tip == 'VİRMAN_TEDARİKÇİ') {
      return _sayi(hareket['borc']) + _sayi(hareket['alacak']);
    }
    return _sayi(hareket['borc']);
  }

  double _gosterimAlacak(Map<String, dynamic> hareket) {
    final tip = _metin(hareket['islem_tipi']).toUpperCase();
    if (tip == 'VIRMAN_TEDARIKCI' || tip == 'VİRMAN_TEDARİKÇİ') return 0;
    return _sayi(hareket['alacak']);
  }

  String _tarih(dynamic deger) {
    final metin = deger?.toString().trim() ?? '';

    if (metin.isEmpty) return '-';

    final tarih = DateTime.tryParse(metin)?.toLocal();

    if (tarih == null) return metin;

    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year} '
        '${tarih.hour.toString().padLeft(2, '0')}:'
        '${tarih.minute.toString().padLeft(2, '0')}';
  }

  double _netEtki(Map<String, dynamic> hareket) {
    return _sayi(hareket['borc']) - _sayi(hareket['alacak']);
  }

  Color _islemRengi(Map<String, dynamic> hareket) {
    final islemTipi = _metin(hareket['islem_tipi']).toUpperCase();

    if (islemTipi.contains('IPTAL') || islemTipi.contains('İPTAL')) {
      return Colors.orange.shade800;
    }

    final etki = _netEtki(hareket);

    if (etki > 0) return Colors.red.shade700;
    if (etki < 0) return Colors.green.shade700;

    return Colors.grey.shade700;
  }

  IconData _islemIkonu(Map<String, dynamic> hareket) {
    final islemTipi = _metin(hareket['islem_tipi']).toUpperCase();

    if (islemTipi.contains('IPTAL') || islemTipi.contains('İPTAL')) {
      return Icons.undo;
    }

    if (islemTipi.contains('TAHSILAT') || islemTipi.contains('TAHSİLAT')) {
      return Icons.payments;
    }

    if (islemTipi.contains('ODEME') || islemTipi.contains('ÖDEME')) {
      return Icons.account_balance_wallet;
    }

    if (islemTipi == 'SATIS' || islemTipi == 'SATIŞ') {
      return Icons.point_of_sale;
    }

    if (islemTipi == 'ALIS' || islemTipi == 'ALIŞ') {
      return Icons.shopping_cart;
    }

    return Icons.swap_horiz;
  }

  String _etkiMetni(Map<String, dynamic> hareket) {
    final etki = _netEtki(hareket);

    if (etki > 0) {
      return '+${_para(etki)}';
    }

    if (etki < 0) {
      return '-${_para(etki.abs())}';
    }

    return _para(0);
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  Future<void> _detayGoster(Map<String, dynamic> hareket) async {
    final islem = _metin(hareket['islem_tipi']).toUpperCase();

    final satisMi = islem == 'SATIS' || islem == 'SATIŞ';

    final alisMi = islem == 'ALIS' || islem == 'ALIŞ';

    if (satisMi || alisMi) {
      await _faturaDetayiGoster(hareket, satisMi: satisMi);
      return;
    }

    final tahsilatMi = islem == 'TAHSILAT' || islem == 'TAHSİLAT';

    final odemeMi = islem == 'ODEME' || islem == 'ÖDEME';

    if (tahsilatMi || odemeMi) {
      await _tahsilatOdemeDetayiGoster(hareket, tahsilatMi: tahsilatMi);
      return;
    }

    await _genelHareketDetayiGoster(hareket);
  }

  Future<Map<String, dynamic>?> _faturaBul(
    Map<String, dynamic> hareket, {
    required bool satisMi,
  }) async {
    final cariId = int.tryParse(hareket['cari_id']?.toString() ?? '');

    if (cariId == null) {
      return null;
    }

    final belgeNoRaw = hareket['belge_no']?.toString().trim() ?? '';

    final belgeNoGecerli = belgeNoRaw.isNotEmpty && belgeNoRaw != '-';

    final tablo = satisMi ? 'satis_baslik' : 'alis_baslik';

    if (belgeNoGecerli) {
      try {
        if (satisMi) {
          final response = await SupabaseService.supabase
              .from(tablo)
              .select()
              .eq('cari_id', cariId)
              .or('fatura_no.eq.$belgeNoRaw,belge_no.eq.$belgeNoRaw')
              .limit(1);

          final liste = List<Map<String, dynamic>>.from(response);

          if (liste.isNotEmpty) {
            return liste.first;
          }
        } else {
          final response = await SupabaseService.supabase
              .from(tablo)
              .select()
              .eq('cari_id', cariId)
              .eq('fatura_no', belgeNoRaw)
              .limit(1);

          final liste = List<Map<String, dynamic>>.from(response);

          if (liste.isNotEmpty) {
            return liste.first;
          }
        }
      } catch (_) {
        // Aşağıdaki tarih/tutar eşleştirmesine geç.
      }
    }

    // Eski cari hareketlerinde belge no "-" kalmış olabilir.
    // Bu durumda aynı carinin yakın tarihli faturaları arasından
    // tarih + genel toplam ile en yakın kaydı bul.
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

    final hareketTutari = (_sayi(hareket['borc']) - _sayi(hareket['alacak']))
        .abs();

    Map<String, dynamic>? enIyi;
    double enIyiPuan = double.infinity;

    for (final fatura in faturalar) {
      final faturaTarihi = DateTime.tryParse(fatura['tarih']?.toString() ?? '')
          ?.toLocal();

      final faturaTutari = _sayi(
        fatura['genel_toplam'] ?? fatura['toplam_tutar'],
      ).abs();

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

      if (hareketTutari > 0 && faturaTutari > 0) {
        final fark = (hareketTutari - faturaTutari).abs();

        // Tutar eşleşmesine güçlü ağırlık ver.
        puan += fark * 1000;
      }

      if (puan < enIyiPuan) {
        enIyiPuan = puan;
        enIyi = fatura;
      }
    }

    return enIyi;
  }

  Future<List<String>> _kaynakIrsaliyeNolariGetir({
    required bool satisMi,
    required int belgeId,
  }) async {
    try {
      final baglantiTablo = satisMi
          ? 'satis_irsaliye_fatura'
          : 'alis_irsaliye_fatura';
      final faturaIdKolonu = satisMi ? 'satis_id' : 'alis_id';
      final irsaliyeTablo = satisMi
          ? 'satis_irsaliye_baslik'
          : 'alis_irsaliye_baslik';

      final baglantilar = await SupabaseService.supabase
          .from(baglantiTablo)
          .select('irsaliye_id')
          .eq(faturaIdKolonu, belgeId);

      final ids = List<Map<String, dynamic>>.from(baglantilar)
          .map((e) => int.tryParse(e['irsaliye_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet()
          .toList();

      if (ids.isEmpty) return [];

      final response = await SupabaseService.supabase
          .from(irsaliyeTablo)
          .select('irsaliye_id, irsaliye_no')
          .inFilter('irsaliye_id', ids)
          .order('irsaliye_id');

      return List<Map<String, dynamic>>.from(response)
          .map((e) => e['irsaliye_no']?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _faturaDetayiGoster(
    Map<String, dynamic> hareket, {
    required bool satisMi,
  }) async {
    try {
      final fatura = await _faturaBul(hareket, satisMi: satisMi);

      if (!mounted) return;

      if (fatura == null) {
        _mesaj(
          '${satisMi ? 'Satış' : 'Alış'} faturası bulunamadı.',
          Colors.orange,
        );
        return;
      }

      final belgeId = int.tryParse(
        fatura[satisMi ? 'satis_id' : 'alis_id']?.toString() ?? '',
      );

      if (belgeId == null) {
        _mesaj('Fatura ID bulunamadı.', Colors.red);
        return;
      }

      final kaynakIrsaliyeNolari = await _kaynakIrsaliyeNolariGetir(
        satisMi: satisMi,
        belgeId: belgeId,
      );

      final detayTablo = satisMi ? 'satis_detay' : 'alis_detay';

      final idKolonu = satisMi ? 'satis_id' : 'alis_id';

      final detayResponse = await SupabaseService.supabase
          .from(detayTablo)
          .select()
          .eq(idKolonu, belgeId);

      final detaylar = List<Map<String, dynamic>>.from(detayResponse);

      final stokIds = detaylar
          .map((detay) => int.tryParse(detay['stok_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet()
          .toList();

      final stokResponse = stokIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await SupabaseService.supabase
                  .from('stoklar')
                  .select(
                    'stok_id, urun_adi, '
                    'uretici_kodu, oem_no, '
                    'marka, raf',
                  )
                  .inFilter('stok_id', stokIds),
            );

      final stokMap = <int, Map<String, dynamic>>{
        for (final stok in stokResponse)
          if (int.tryParse(stok['stok_id']?.toString() ?? '') != null)
            int.parse(stok['stok_id'].toString()): stok,
      };

      for (final detay in detaylar) {
        final stokId = int.tryParse(detay['stok_id']?.toString() ?? '');

        final stok = stokId == null ? null : stokMap[stokId];

        detay['urun_adi'] = stok?['urun_adi'] ?? '-';
        detay['uretici_kodu'] = stok?['uretici_kodu'] ?? '-';
        detay['oem_no'] = stok?['oem_no'] ?? '-';
        detay['marka'] = stok?['marka'] ?? '-';
        detay['raf'] = stok?['raf'] ?? '-';
      }

      String depoAdi = '-';
      String kasaAdi = '-';

      final depoId = int.tryParse(fatura['depo_id']?.toString() ?? '');

      final kasaId = int.tryParse(fatura['kasa_id']?.toString() ?? '');

      if (depoId != null) {
        try {
          final depoResponse = await SupabaseService.supabase
              .from('depolar')
              .select('depo_id, depo_adi')
              .eq('depo_id', depoId)
              .limit(1);

          final liste = List<Map<String, dynamic>>.from(depoResponse);

          if (liste.isNotEmpty) {
            depoAdi = _metin(liste.first['depo_adi']);
          }
        } catch (e) {
          debugPrint('PRO ERP sessiz hata [$e]');
        }
      }

      if (kasaId != null) {
        try {
          final kasaResponse = await SupabaseService.supabase
              .from('kasalar')
              .select('kasa_id, kasa_adi')
              .eq('kasa_id', kasaId)
              .limit(1);

          final liste = List<Map<String, dynamic>>.from(kasaResponse);

          if (liste.isNotEmpty) {
            kasaAdi = _metin(liste.first['kasa_adi']);
          }
        } catch (e) {
          debugPrint('PRO ERP sessiz hata [$e]');
        }
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            title: MobilYatayRow(
              children: [
                Icon(
                  satisMi ? Icons.point_of_sale : Icons.shopping_cart,
                  color: satisMi ? Colors.blue.shade700 : Colors.teal.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${satisMi ? 'Satış' : 'Alış'} Faturası: '
                        '${_metin(fatura['fatura_no'])}',
                      ),
                      const SizedBox(height: 2),
                      Text(
                        satisMi
                            ? 'Bu cariye hangi ürünün hangi fiyattan çıktığı'
                            : 'Bu cariden hangi ürünün hangi fiyattan alındığı',
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
                        _faturaBilgisi('Cari', _metin(hareket['cari_unvan'])),
                        _faturaBilgisi(
                          'Fatura No',
                          _metin(fatura['fatura_no']),
                        ),
                        _faturaBilgisi(
                          'İrsaliye No',
                          kaynakIrsaliyeNolari.isEmpty
                              ? '-'
                              : kaynakIrsaliyeNolari.join(', '),
                        ),
                        if (satisMi)
                          _faturaBilgisi(
                            'Belge No',
                            _metin(fatura['belge_no']),
                          ),
                        _faturaBilgisi('Tarih', _tarih(fatura['tarih'])),
                        _faturaBilgisi('Depo', depoAdi),
                        _faturaBilgisi(
                          'Ödeme Tipi',
                          _metin(fatura['odeme_tipi']),
                        ),
                        _faturaBilgisi('Kasa / Banka', kasaAdi),
                        _faturaBilgisi('Durum', _metin(fatura['durum'])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: detaylar.isEmpty
                        ? Center(
                            child: Text(
                              'Bu faturaya ait ürün bulunamadı.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
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

                                        final birimFiyat = _sayi(
                                          detay['birim_fiyat'],
                                        );

                                        final indirim = _sayi(
                                          detay['indirim'] ??
                                              detay['indirim_orani'],
                                        );

                                        final kdv = _sayi(
                                          detay['kdv'] ?? detay['kdv_orani'],
                                        );

                                        final net =
                                            miktar *
                                            birimFiyat *
                                            (1 - indirim / 100);

                                        final hesaplananToplam =
                                            net * (1 + kdv / 100);

                                        final kayitliToplam = _sayi(
                                          detay['tutar'] ?? detay['toplam'],
                                        );

                                        final satirToplami = kayitliToplam > 0
                                            ? kayitliToplam
                                            : hesaplananToplam;

                                        return DataRow(
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
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                _metin(detay['uretici_kodu']),
                                              ),
                                            ),
                                            DataCell(
                                              Text(_metin(detay['raf'])),
                                            ),
                                            DataCell(
                                              Text(
                                                miktar.toStringAsFixed(
                                                  miktar ==
                                                          miktar.roundToDouble()
                                                      ? 0
                                                      : 2,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                _para(birimFiyat),
                                                style: TextStyle(
                                                  color: satisMi
                                                      ? Colors.blue.shade700
                                                      : Colors.teal.shade700,
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
                                                _para(satirToplami),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _faturaToplamKutusu(
                          'Ara Toplam',
                          _para(fatura['toplam_tutar']),
                        ),
                        _faturaToplamKutusu('KDV', _para(fatura['kdv_toplam'])),
                        _faturaToplamKutusu(
                          'Genel Toplam',
                          _para(
                            fatura['genel_toplam'] ?? fatura['toplam_tutar'],
                          ),
                          vurgu: true,
                          renk: satisMi ? Colors.blue : Colors.teal,
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
    } catch (e) {
      if (!mounted) return;

      _mesaj(
        '${satisMi ? 'Satış' : 'Alış'} fatura detayı yüklenemedi: $e',
        Colors.red,
      );
    }
  }

  Future<Map<String, dynamic>?> _kasaHareketiBul(
    Map<String, dynamic> cariHareket,
    bool tahsilatMi,
  ) async {
    final cariId = int.tryParse(cariHareket['cari_id']?.toString() ?? '');

    if (cariId == null) return null;

    final belgeNo = cariHareket['belge_no']?.toString().trim() ?? '';

    final beklenenTipler = tahsilatMi
        ? ['TAHSILAT', 'TAHSİLAT']
        : ['ODEME', 'ÖDEME'];

    try {
      var query = SupabaseService.supabase
          .from('kasa_hareket')
          .select(
            'hareket_id, tarih, kasa_id, tip, tutar, '
            'belge_no, aciklama, cari_id, kullanici',
          )
          .eq('cari_id', cariId);

      if (belgeNo.isNotEmpty && belgeNo != '-') {
        final response = await query
            .eq('belge_no', belgeNo)
            .order('tarih', ascending: false)
            .limit(10);

        final liste = List<Map<String, dynamic>>.from(response);

        for (final item in liste) {
          final tip = _metin(item['tip']).toUpperCase();

          if (beklenenTipler.contains(tip)) {
            return item;
          }
        }

        if (liste.isNotEmpty) {
          return liste.first;
        }
      }

      // Eski kayıtlarda belge no "-" olabilir.
      // Cari + tip + tarih/tutar yakınlığıyla en uygun kasa hareketini bul.
      final response = await SupabaseService.supabase
          .from('kasa_hareket')
          .select(
            'hareket_id, tarih, kasa_id, tip, tutar, '
            'belge_no, aciklama, cari_id, kullanici',
          )
          .eq('cari_id', cariId)
          .order('tarih', ascending: false)
          .limit(50);

      final liste = List<Map<String, dynamic>>.from(response);

      final hareketTarihi = DateTime.tryParse(
        cariHareket['tarih']?.toString() ?? '',
      )?.toLocal();

      final cariTutar = tahsilatMi
          ? _sayi(cariHareket['alacak']).abs()
          : _sayi(cariHareket['borc']).abs();

      Map<String, dynamic>? enIyi;
      double enIyiPuan = double.infinity;

      for (final item in liste) {
        final tip = _metin(item['tip']).toUpperCase();

        if (!beklenenTipler.contains(tip)) {
          continue;
        }

        final kasaTarihi = DateTime.tryParse(item['tarih']?.toString() ?? '')
            ?.toLocal();

        final kasaTutar = _sayi(item['tutar']).abs();

        double puan = 0;

        if (hareketTarihi != null && kasaTarihi != null) {
          puan += hareketTarihi
              .difference(kasaTarihi)
              .inSeconds
              .abs()
              .toDouble();
        } else {
          puan += 1000000;
        }

        puan += (cariTutar - kasaTutar).abs() * 1000;

        if (puan < enIyiPuan) {
          enIyiPuan = puan;
          enIyi = item;
        }
      }

      return enIyi;
    } catch (_) {
      return null;
    }
  }

  Future<void> _tahsilatOdemeDetayiGoster(
    Map<String, dynamic> hareket, {
    required bool tahsilatMi,
  }) async {
    final kasaHareket = await _kasaHareketiBul(hareket, tahsilatMi);

    String kasaAdi = '-';

    final kasaId = int.tryParse(kasaHareket?['kasa_id']?.toString() ?? '');

    if (kasaId != null) {
      try {
        final response = await SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi, kasa_tipi')
            .eq('kasa_id', kasaId)
            .limit(1);

        final liste = List<Map<String, dynamic>>.from(response);

        if (liste.isNotEmpty) {
          kasaAdi = _metin(liste.first['kasa_adi']);
        }
      } catch (e) {
        debugPrint('PRO ERP sessiz hata [$e]');
      }
    }

    if (!mounted) return;

    final renk = tahsilatMi ? Colors.green : Colors.orange;

    final tutar = kasaHareket != null
        ? _sayi(kasaHareket['tutar'])
        : (tahsilatMi ? _sayi(hareket['alacak']) : _sayi(hareket['borc']));

    final belgeNo = _metin(kasaHareket?['belge_no'] ?? hareket['belge_no']);

    final tarih = kasaHareket?['tarih'] ?? hareket['tarih'];

    final kullanici = _metin(kasaHareket?['kullanici'] ?? hareket['kullanici']);

    final aciklama = _metin(kasaHareket?['aciklama'] ?? hareket['aciklama']);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          title: MobilYatayRow(
            children: [
              Icon(
                tahsilatMi
                    ? Icons.payments_rounded
                    : Icons.account_balance_wallet_rounded,
                color: renk.shade700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tahsilatMi ? 'Tahsilat Makbuzu' : 'Ödeme Makbuzu'),
              ),
            ],
          ),
          content: MobilDialogIcerik(
            width: 920,
            height: 520,
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
                    runSpacing: 14,
                    children: [
                      _faturaBilgisi('Cari', _metin(hareket['cari_unvan'])),
                      _faturaBilgisi(
                        'İşlem',
                        tahsilatMi ? 'TAHSİLAT' : 'ÖDEME',
                      ),
                      _faturaBilgisi('Belge No', belgeNo),
                      _faturaBilgisi('Tarih', _tarih(tarih)),
                      _faturaBilgisi('Kasa / Banka', kasaAdi),
                      _faturaBilgisi('Kullanıcı', kullanici),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: renk.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: renk.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tahsilatMi
                              ? 'CARİDEN TAHSİL EDİLEN'
                              : 'CARİYE YAPILAN ÖDEME',
                          style: TextStyle(
                            color: renk.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _para(tutar),
                          style: TextStyle(
                            color: renk.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 34,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          'Açıklama',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          aciklama,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        MobilYatayRow(
                          children: [
                            Expanded(
                              child: _makbuzOzetKutusu(
                                'Borç',
                                _para(_gosterimBorc(hareket)),
                                Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _makbuzOzetKutusu(
                                'Alacak',
                                _para(_gosterimAlacak(hareket)),
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _makbuzOzetKutusu(
                                'Bakiye Etkisi',
                                _etkiMetni(hareket),
                                renk,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

  Widget _makbuzOzetKutusu(String baslik, String deger, MaterialColor renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            deger,
            style: TextStyle(
              color: renk.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _genelHareketDetayiGoster(Map<String, dynamic> hareket) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: MobilYatayRow(
            children: [
              Icon(_islemIkonu(hareket), color: _islemRengi(hareket)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Cari Hareket Detayı')),
            ],
          ),
          content: MobilDialogIcerik(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detaySatiri('Cari', _metin(hareket['cari_unvan'])),
                  _detaySatiri('Cari Tipi', _metin(hareket['cari_tipi'])),
                  _detaySatiri('İşlem Tipi', _metin(hareket['islem_tipi'])),
                  _detaySatiri(
                    'İrsaliye No',
                    _metin(hareket['irsaliye_no'] ?? hareket['belge_no']),
                  ),
                  _detaySatiri('Fatura No', _metin(hareket['fatura_no'])),
                  const Divider(height: 24),
                  _detaySatiri(
                    'Borç',
                    _para(_gosterimBorc(hareket)),
                    renk: Colors.red.shade700,
                    kalin: true,
                  ),
                  _detaySatiri(
                    'Alacak',
                    _para(_gosterimAlacak(hareket)),
                    renk: Colors.green.shade700,
                    kalin: true,
                  ),
                  _detaySatiri(
                    'Bakiye Etkisi',
                    _etkiMetni(hareket),
                    renk: _islemRengi(hareket),
                    kalin: true,
                  ),
                  _detaySatiri(
                    'Güncel Cari Bakiyesi',
                    _para(hareket['cari_bakiye']),
                  ),
                  const Divider(height: 24),
                  _detaySatiri('Tarih', _tarih(hareket['tarih'])),
                  _detaySatiri('Kullanıcı', _metin(hareket['kullanici'])),
                  _detaySatiri('Açıklama', _metin(hareket['aciklama'])),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
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

  Widget _faturaBilgisi(String baslik, String deger) {
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

  Widget _faturaToplamKutusu(
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

  Widget _detaySatiri(
    String baslik,
    String deger, {
    Color? renk,
    bool kalin = false,
  }) {
    final mobil = MobilUyum.telefon(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: mobil
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  deger,
                  style: TextStyle(
                    color: renk,
                    fontWeight: kalin ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            )
          : MobilYatayRow(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 155,
                  child: Text(
                    baslik,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: Text(
                    deger,
                    style: TextStyle(
                      color: renk,
                      fontWeight: kalin ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _hareketKarti(Map<String, dynamic> hareket) {
    final renk = _islemRengi(hareket);

    if (MobilUyum.telefon(context)) {
      return _mobilHareketKarti(hareket, renk);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _detayGoster(hareket);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: MobilYatayRow(
            children: [
              CircleAvatar(
                backgroundColor: renk.withOpacity(0.14),
                child: Icon(_islemIkonu(hareket), color: renk),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metin(hareket['cari_unvan']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Text('Tip: ${_metin(hareket['cari_tipi'])}'),
                        Text('Belge: ${_metin(hareket['belge_no'])}'),
                        Text('Kullanıcı: ${_metin(hareket['kullanici'])}'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metin(hareket['islem_tipi']),
                      style: TextStyle(
                        color: renk,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tarih(hareket['tarih']),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 145,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _etkiMetni(hareket),
                      style: TextStyle(
                        color: renk,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Borç: ${_para(_gosterimBorc(hareket))}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      'Alacak: ${_para(_gosterimAlacak(hareket))}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Detay',
                onPressed: () {
                  _detayGoster(hareket);
                },
                icon: const Icon(Icons.visibility),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobilHareketKarti(Map<String, dynamic> hareket, Color renk) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _detayGoster(hareket),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: renk.withOpacity(0.14),
                    child: Icon(_islemIkonu(hareket), color: renk),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _metin(hareket['cari_unvan']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _metin(hareket['islem_tipi']),
                          style: TextStyle(
                            color: renk,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _etkiMetni(hareket),
                    style: TextStyle(
                      color: renk,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  Text('Tip: ${_metin(hareket['cari_tipi'])}'),
                  Text('Belge: ${_metin(hareket['belge_no'])}'),
                  Text('Borç: ${_para(_gosterimBorc(hareket))}'),
                  Text('Alacak: ${_para(_gosterimAlacak(hareket))}'),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kullanıcı: ${_metin(hareket['kullanici'])}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  Text(_tarih(hareket['tarih'])),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MobilUyum.telefon(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'CARİ HAREKETLERİ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          MobilAppBarActions(
            children: [
              IconButton(
                tooltip: 'Yenile',
                onPressed: _verileriYukle,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: mobil ? double.infinity : 390,
                  child: TextField(
                    controller: _aramaController,
                    decoration: InputDecoration(
                      hintText: 'Cari, belge no, işlem tipi, açıklama...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _aramaController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Temizle',
                              onPressed: () {
                                _aramaController.clear();
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: mobil ? double.infinity : 270,
                  child: DropdownButtonFormField<int?>(
                    value: _secilenCariId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cari',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tüm Cariler'),
                      ),
                      ..._cariler.map((cari) {
                        return DropdownMenuItem<int?>(
                          value: int.tryParse(cari['cari_id'].toString()),
                          child: Text(
                            cari['unvan']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (deger) {
                      setState(() {
                        _secilenCariId = deger;
                      });

                      _filtrele();
                    },
                  ),
                ),
                SizedBox(
                  width: mobil ? double.infinity : 180,
                  child: DropdownButtonFormField<String>(
                    value: _islemFiltresi,
                    decoration: const InputDecoration(
                      labelText: 'İşlem',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'TÜMÜ',
                        child: Text('Tüm Hareketler'),
                      ),
                      DropdownMenuItem(value: 'SATIŞ', child: Text('Satış')),
                      DropdownMenuItem(value: 'ALIŞ', child: Text('Alış')),
                      DropdownMenuItem(
                        value: 'TAHSİLAT',
                        child: Text('Tahsilat'),
                      ),
                      DropdownMenuItem(value: 'ÖDEME', child: Text('Ödeme')),
                      DropdownMenuItem(value: 'İPTAL', child: Text('İptaller')),
                    ],
                    onChanged: (deger) {
                      if (deger == null) return;

                      setState(() {
                        _islemFiltresi = deger;
                      });

                      _filtrele();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _gorunenHareketler.isEmpty
                ? const Center(
                    child: Text(
                      'Cari hareketi bulunamadı.',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _verileriYukle,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _gorunenHareketler.length,
                      separatorBuilder: (_, __) {
                        return const SizedBox(height: 8);
                      },
                      itemBuilder: (context, index) {
                        return _hareketKarti(_gorunenHareketler[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
