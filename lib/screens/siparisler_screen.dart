// lib/screens/siparisler_screen.dart

import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import '../services/supabase_service.dart';
import '../services/yetki_service.dart';
import '../services/kurumsal_yazdirma_service.dart';
import '../services/calisma_sekmesi_service.dart';
import '../utils/marka_kod.dart';
import 'yeni_siparis_screen.dart';

class SiparislerScreen extends StatefulWidget {
  const SiparislerScreen({super.key});

  @override
  State<SiparislerScreen> createState() =>
      _SiparislerScreenState();
}

class _SiparislerScreenState extends State<SiparislerScreen> {
  final TextEditingController _aramaController =
      TextEditingController();

  bool _yukleniyor = true;
  bool _islemYapiliyor = false;

  String _durumFiltresi = 'TÜMÜ';

  List<Map<String, dynamic>> _tumSiparisler = [];
  List<Map<String, dynamic>> _gorunenSiparisler = [];

  Map<int, String> _cariHaritasi = {};
  Map<int, String> _depoHaritasi = {};
  List<Map<String, dynamic>> _kasalar = [];

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

  Future<void> _yeniKayitAc() async {
    final sekmedeAcildi = CalismaSekmesiService.ac(
      'yeni_satis_siparisi',
      'Yeni Satış Siparişi',
      const YeniSiparisScreen(),
    );
    if (sekmedeAcildi) return;

    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const YeniSiparisScreen(
          kayitSonrasiKapat: true,
        ),
      ),
    );

    if (!mounted) return;

    if (sonuc == true) {
      await _verileriYukle();

      _mesaj(
        'Yeni kayıt listeye eklendi.',
        Colors.green,
      );
    }
  }

  Future<void> _verileriYukle() async {
    if (!mounted) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from('satis_siparis_baslik')
            .select()
            .order('tarih', ascending: false),
        SupabaseService.supabase
            .from('cariler')
            .select('cari_id, unvan'),
        SupabaseService.supabase
            .from('depolar')
            .select('depo_id, depo_adi'),
        SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi')
            .order('kasa_adi'),
      ]);

      final siparisler =
          List<Map<String, dynamic>>.from(sonuclar[0] as List);

      final cariler =
          List<Map<String, dynamic>>.from(sonuclar[1] as List);

      final depolar =
          List<Map<String, dynamic>>.from(sonuclar[2] as List);

      final kasalar =
          List<Map<String, dynamic>>.from(sonuclar[3] as List);

      final cariHaritasi = <int, String>{};
      final depoHaritasi = <int, String>{};

      for (final cari in cariler) {
        final id = int.tryParse(
          cari['cari_id']?.toString() ?? '',
        );

        if (id != null) {
          cariHaritasi[id] =
              cari['unvan']?.toString() ?? '';
        }
      }

      for (final depo in depolar) {
        final id = int.tryParse(
          depo['depo_id']?.toString() ?? '',
        );

        if (id != null) {
          depoHaritasi[id] =
              depo['depo_adi']?.toString() ?? '';
        }
      }

      if (!mounted) return;

      setState(() {
        _tumSiparisler = siparisler;
        _gorunenSiparisler = siparisler;
        _cariHaritasi = cariHaritasi;
        _depoHaritasi = depoHaritasi;
        _kasalar = kasalar;
        _yukleniyor = false;
      });

      _filtrele();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      _mesaj(
        'Siparişler yüklenemedi: $e',
        Colors.red,
      );
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
      _gorunenSiparisler =
          _tumSiparisler.where((siparis) {
        final durum =
            _metin(siparis['durum']).toUpperCase();

        if (_durumFiltresi != 'TÜMÜ' &&
            durum != _durumFiltresi) {
          return false;
        }

        if (kelimeler.isEmpty) return true;

        final metin = [
          siparis['siparis_no'],
          _cariAdi(siparis['cari_id']),
          _depoAdi(siparis['depo_id']),
          siparis['durum'],
          siparis['kullanici'],
          siparis['aciklama'],
        ].map(
          (deger) => deger?.toString() ?? '',
        ).join(' ').toLowerCase();

        return kelimeler.every(metin.contains);
      }).toList();
    });
  }

  String _metin(dynamic deger) {
    final sonuc = deger?.toString().trim() ?? '';
    return sonuc.isEmpty ? '-' : sonuc;
  }

  double _sayi(dynamic deger) {
    return double.tryParse(
          deger?.toString().replaceAll(',', '.') ?? '0',
        ) ??
        0.0;
  }

  String _para(dynamic deger) {
    return '${_sayi(deger).toStringAsFixed(2)} ₺';
  }

  String _tarih(dynamic deger) {
    final raw = deger?.toString().trim() ?? '';

    if (raw.isEmpty) return '-';

    final tarih = DateTime.tryParse(raw)?.toLocal();

    if (tarih == null) return raw;

    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year} '
        '${tarih.hour.toString().padLeft(2, '0')}:'
        '${tarih.minute.toString().padLeft(2, '0')}';
  }

  String _cariAdi(dynamic cariId) {
    final id = int.tryParse(cariId?.toString() ?? '');
    if (id == null) return '-';

    return _cariHaritasi[id] ?? '-';
  }

  String _depoAdi(dynamic depoId) {
    final id = int.tryParse(depoId?.toString() ?? '');
    if (id == null) return '-';

    return _depoHaritasi[id] ?? '-';
  }

  Color _durumRengi(dynamic durum) {
    final metin = _metin(durum).toUpperCase();

    switch (metin) {
      case 'HAZIRLANIYOR':
        return Colors.orange;
      case 'ONAYLANDI':
        return Colors.blue;
      case 'KISMI_SEVK':
        return Colors.purple;
      case 'TAMAMLANDI':
        return Colors.green;
      case 'IPTAL':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<List<Map<String, dynamic>>> _detaylariGetir(
    int siparisId,
  ) async {
    final response = await SupabaseService.supabase
        .from('satis_siparis_detay')
        .select(
          'detay_id, siparis_id, stok_id, miktar, '
          'sevk_edilen_miktar, kalan_miktar, birim_fiyat, '
          'indirim_orani, kdv_orani, genel_toplam, durum, aciklama',
        )
        .eq('siparis_id', siparisId)
        .order('detay_id');

    final detaylar =
        List<Map<String, dynamic>>.from(response);

    final stokIds = detaylar
        .map(
          (detay) =>
              int.tryParse(detay['stok_id']?.toString() ?? ''),
        )
        .whereType<int>()
        .toSet()
        .toList();

    final stokHaritasi = <int, Map<String, dynamic>>{};

    if (stokIds.isNotEmpty) {
      final stokResponse = await SupabaseService.supabase
          .from('stoklar')
          .select(
            'stok_id, urun_adi, uretici_kodu, oem_no, marka, raf, stok_miktari',
          )
          .inFilter('stok_id', stokIds);

      for (final stok
          in List<Map<String, dynamic>>.from(stokResponse)) {
        final id = int.tryParse(
          stok['stok_id']?.toString() ?? '',
        );

        if (id != null) {
          stokHaritasi[id] = stok;
        }
      }
    }

    for (final detay in detaylar) {
      final stokId = int.tryParse(
        detay['stok_id']?.toString() ?? '',
      );

      final stok = stokId == null
          ? null
          : stokHaritasi[stokId];

      detay['urun_adi'] =
          stok?['urun_adi']?.toString() ?? '-';

      detay['uretici_kodu'] =
          stok?['uretici_kodu']?.toString() ?? '-';

      detay['oem_no'] =
          stok?['oem_no']?.toString() ?? '-';

      detay['marka'] =
          stok?['marka']?.toString() ?? '-';

      detay['raf'] =
          stok?['raf']?.toString() ?? '-';

      detay['stok_miktari'] =
          stok?['stok_miktari'] ?? 0;
    }

    return detaylar;
  }

  Future<void> _detayGoster(
    Map<String, dynamic> siparis,
  ) async {
    final siparisId = int.tryParse(
      siparis['siparis_id']?.toString() ?? '',
    );

    if (siparisId == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _detaylariGetir(siparisId),
          builder: (context, snapshot) {
            final detaylar =
                snapshot.data ?? <Map<String, dynamic>>[];

            final araToplam = detaylar.fold<double>(
              0,
              (toplam, detay) =>
                  toplam + _satirBrut(detay),
            );

            final indirimToplam = detaylar.fold<double>(
              0,
              (toplam, detay) =>
                  toplam + _satirIndirim(detay),
            );

            final kdvToplam = detaylar.fold<double>(
              0,
              (toplam, detay) =>
                  toplam + _satirKdv(detay),
            );

            final genelToplam =
                araToplam - indirimToplam + kdvToplam;

            final durumRengi =
                _durumRengi(siparis['durum']);

            return AlertDialog(
              insetPadding: const EdgeInsets.all(18),
              titlePadding: const EdgeInsets.fromLTRB(
                22,
                18,
                16,
                8,
              ),
              contentPadding: const EdgeInsets.fromLTRB(
                22,
                8,
                22,
                10,
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                16,
                4,
                16,
                14,
              ),
              title: MobilYatayRow(
                children: [
                  const Icon(
                    Icons.assignment_rounded,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Satış Siparişi: '
                      '${_metin(siparis['siparis_no'])}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: durumRengi.withOpacity(0.10),
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: Text(
                      _metin(siparis['durum']),
                      style: TextStyle(
                        color: durumRengi,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              content: MobilDialogIcerik(
                width: 1080,
                height: 700,
                child: snapshot.connectionState ==
                        ConnectionState.waiting
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : snapshot.hasError
                        ? Center(
                            child: Text(
                              'Detaylar yüklenemedi: '
                              '${snapshot.error}',
                            ),
                          )
                        : Column(
                            children: [
                              Container(
                                width: 900,
                                padding:
                                    const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        Colors.grey.shade300,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(
                                    12,
                                  ),
                                ),
                                child: Wrap(
                                  spacing: 24,
                                  runSpacing: 16,
                                  children: [
                                    _ustBilgi(
                                      'Sipariş No',
                                      _metin(
                                        siparis[
                                            'siparis_no'],
                                      ),
                                    ),
                                    _ustBilgi(
                                      'Cari / Müşteri',
                                      _cariAdi(
                                        siparis['cari_id'],
                                      ),
                                    ),
                                    _ustBilgi(
                                      'Tarih',
                                      _tarih(
                                        siparis['tarih'],
                                      ),
                                    ),
                                    _ustBilgi(
                                      'Durum',
                                      _metin(
                                        siparis['durum'],
                                      ),
                                    ),
                                    _ustBilgi(
                                      'Depo',
                                      _depoAdi(
                                        siparis['depo_id'],
                                      ),
                                    ),
                                    _ustBilgi(
                                      'Termin',
                                      _tarih(
                                        siparis[
                                            'termin_tarihi'],
                                      ),
                                    ),
                                    _ustBilgi(
                                      'Ödeme Tipi',
                                      _metin(
                                        siparis[
                                            'odeme_tipi'],
                                      ),
                                    ),
                                    _ustBilgi(
                                      'Kullanıcı',
                                      _metin(
                                        siparis[
                                            'kullanici'],
                                      ),
                                    ),
                                    _ustBilgi(
                                      'Açıklama',
                                      _metin(
                                        siparis[
                                            'aciklama'],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Expanded(
                                child: detaylar.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'Sipariş kalemi bulunamadı.',
                                        ),
                                      )
                                    : Container(
                                        decoration:
                                            BoxDecoration(
                                          border: Border.all(
                                            color: Colors
                                                .grey.shade300,
                                          ),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(10),
                                        ),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal: 12,
                                                vertical: 11,
                                              ),
                                              decoration:
                                                  BoxDecoration(
                                                color: Colors
                                                    .grey.shade100,
                                                borderRadius:
                                                    const BorderRadius
                                                        .vertical(
                                                  top: Radius
                                                      .circular(10),
                                                ),
                                              ),
                                              child: const MobilYatayRow(
                                                children: [
                                                  Expanded(
                                                    flex: 4,
                                                    child: Text(
                                                      'Ürün',
                                                      style:
                                                          TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'Marka / Kod',
                                                      style:
                                                          TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'RAF',
                                                      style:
                                                          TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      'Miktar',
                                                      style:
                                                          TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      'Sevk',
                                                      style:
                                                          TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      'Kalan',
                                                      style:
                                                          TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'Birim Fiyat',
                                                      style:
                                                          TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      'KDV %',
                                                      style:
                                                          TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      'Tutar',
                                                      textAlign:
                                                          TextAlign
                                                              .end,
                                                      style:
                                                          TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: ListView
                                                  .separated(
                                                itemCount:
                                                    detaylar.length,
                                                separatorBuilder:
                                                    (_, __) =>
                                                        const Divider(
                                                  height: 1,
                                                ),
                                                itemBuilder:
                                                    (context,
                                                        index) {
                                                  final detay =
                                                      detaylar[
                                                          index];

                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal:
                                                          12,
                                                      vertical: 13,
                                                    ),
                                                    child: MobilYatayRow(
                                                      children: [
                                                        Expanded(
                                                          flex: 4,
                                                          child: Text(
                                                            _metin(
                                                              detay[
                                                                  'urun_adi'],
                                                            ),
                                                            maxLines:
                                                                2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Text(
                                                            markaVeUreticiKodu(
                                                              detay['marka'],
                                                              detay['uretici_kodu'],
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Text(
                                                            _metin(
                                                              detay[
                                                                  'raf'],
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            _miktar(
                                                              detay[
                                                                  'miktar'],
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            _miktar(
                                                              detay[
                                                                  'sevk_edilen_miktar'],
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            _miktar(
                                                              detay[
                                                                  'kalan_miktar'],
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Text(
                                                            _para(
                                                              detay[
                                                                  'birim_fiyat'],
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            _sayi(
                                                              detay[
                                                                  'kdv_orani'],
                                                            ).toStringAsFixed(
                                                              0,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Text(
                                                            _para(
                                                              _satirMatrah(
                                                                detay,
                                                              ),
                                                            ),
                                                            textAlign:
                                                                TextAlign
                                                                    .end,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              Align(
                                alignment:
                                    Alignment.centerRight,
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _toplamKutusu(
                                      'Ara Toplam',
                                      _para(araToplam),
                                    ),
                                    if (indirimToplam > 0)
                                      _toplamKutusu(
                                        'İndirim',
                                        _para(
                                          indirimToplam,
                                        ),
                                      ),
                                    _toplamKutusu(
                                      'KDV',
                                      _para(kdvToplam),
                                    ),
                                    _toplamKutusu(
                                      'Genel Toplam',
                                      _para(genelToplam),
                                      vurgu: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
              ),
              actions: [
                if ([
                  'ONAYLANDI',
                  'KISMI_SEVK',
                ].contains(
                  _metin(siparis['durum'])
                      .toUpperCase(),
                ))
                  ElevatedButton.icon(
                    onPressed: _islemYapiliyor ||
                            snapshot.data == null
                        ? null
                        : () async {
                            Navigator.pop(
                              dialogContext,
                            );
                            await _siparisiFaturala(
                              siparis,
                              snapshot.data!,
                            );
                          },
                    icon: const Icon(
                      Icons.receipt_long_rounded,
                    ),
                    label: const Text(
                      'Siparişi Faturala',
                    ),
                  ),
                if (_metin(siparis['durum'])
                        .toUpperCase() ==
                    'HAZIRLANIYOR')
                  OutlinedButton.icon(
                    onPressed: _islemYapiliyor
                        ? null
                        : () async {
                            Navigator.pop(
                              dialogContext,
                            );
                            await _siparisiOnayla(
                              siparis,
                            );
                          },
                    icon: const Icon(
                      Icons.check_rounded,
                    ),
                    label: const Text('Onayla'),
                  ),
                if (![
                  'TAMAMLANDI',
                  'IPTAL',
                ].contains(
                  _metin(siparis['durum'])
                      .toUpperCase(),
                ))
                  OutlinedButton.icon(
                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: _islemYapiliyor
                        ? null
                        : () async {
                            Navigator.pop(
                              dialogContext,
                            );
                            await _siparisiIptalEt(
                              siparis,
                            );
                          },
                    icon: const Icon(
                      Icons.cancel_rounded,
                    ),
                    label:
                        const Text('İptal Et'),
                  ),
                OutlinedButton.icon(
                  onPressed: snapshot.hasData && !_islemYapiliyor
                      ? () async {
                          try {
                            final yazdirSiparis = Map<String, dynamic>.from(siparis);
                            yazdirSiparis['cari_unvan'] = _cariAdi(siparis['cari_id']);
                            yazdirSiparis['depo_adi'] = _depoAdi(siparis['depo_id']);
                            await KurumsalYazdirmaService.siparisYazdir(
                              satis: true,
                              siparis: yazdirSiparis,
                              detaylar: snapshot.data!,
                            );
                          } catch (e) {
                            if (mounted) {
                              _mesaj('Sipariş yazdırılamadı: $e', Colors.red);
                            }
                          }
                        }
                      : null,
                  icon: const Icon(
                    Icons.print_rounded,
                  ),
                  label: const Text('Yazdır'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text('Kapat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _miktar(dynamic deger) {
    final sayi = _sayi(deger);

    if (sayi == sayi.roundToDouble()) {
      return sayi.toStringAsFixed(0);
    }

    return sayi.toStringAsFixed(3);
  }

  double _satirBrut(
    Map<String, dynamic> detay,
  ) {
    return _sayi(detay['miktar']) *
        _sayi(detay['birim_fiyat']);
  }

  double _satirIndirim(
    Map<String, dynamic> detay,
  ) {
    return _satirBrut(detay) *
        _sayi(detay['indirim_orani']) /
        100;
  }

  double _satirMatrah(
    Map<String, dynamic> detay,
  ) {
    return _satirBrut(detay) -
        _satirIndirim(detay);
  }

  double _satirKdv(
    Map<String, dynamic> detay,
  ) {
    return _satirMatrah(detay) *
        _sayi(detay['kdv_orani']) /
        100;
  }

  Widget _ustBilgi(
    String baslik,
    String deger,
  ) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            deger,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toplamKutusu(
    String baslik,
    String deger, {
    bool vurgu = false,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: vurgu
            ? Colors.teal.withOpacity(0.10)
            : Colors.white,
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          Text(
            baslik,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            deger,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: vurgu
                  ? Colors.teal.shade700
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _siparisiOnayla(
    Map<String, dynamic> siparis,
  ) async {
    final siparisId = int.tryParse(
      siparis['siparis_id']?.toString() ?? '',
    );

    if (siparisId == null) return;

    setState(() {
      _islemYapiliyor = true;
    });

    try {
      await SupabaseService.supabase.rpc(
        'satis_siparis_onayla',
        params: {
          'p_siparis_id': siparisId,
          'p_kullanici': YetkiService.aktifKullanici,
        },
      );

      if (!mounted) return;

      _mesaj(
        'Sipariş onaylandı.',
        Colors.green,
      );

      await _verileriYukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj(
        'Sipariş onay hatası: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _islemYapiliyor = false;
        });
      }
    }
  }

  Future<void> _siparisiIptalEt(
    Map<String, dynamic> siparis,
  ) async {
    final siparisId = int.tryParse(
      siparis['siparis_id']?.toString() ?? '',
    );

    if (siparisId == null) return;

    final aciklamaController =
        TextEditingController();

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Siparişi İptal Et',
          ),
          content: TextField(
            controller: aciklamaController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'İptal Açıklaması',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('İptal Et'),
            ),
          ],
        );
      },
    );

    final aciklama =
        aciklamaController.text.trim();

    aciklamaController.dispose();

    if (onay != true) return;

    setState(() {
      _islemYapiliyor = true;
    });

    try {
      await SupabaseService.supabase.rpc(
        'satis_siparis_iptal_et',
        params: {
          'p_siparis_id': siparisId,
          'p_kullanici': YetkiService.aktifKullanici,
          'p_aciklama': aciklama,
        },
      );

      if (!mounted) return;

      _mesaj(
        'Sipariş iptal edildi.',
        Colors.green,
      );

      await _verileriYukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj(
        'Sipariş iptal hatası: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _islemYapiliyor = false;
        });
      }
    }
  }


  Future<void> _siparisiFaturala(
    Map<String, dynamic> siparis,
    List<Map<String, dynamic>> detaylar,
  ) async {
    if (_islemYapiliyor) return;

    final siparisId = int.tryParse(
      siparis['siparis_id']?.toString() ?? '',
    );

    if (siparisId == null) return;

    final secilebilirDetaylar = detaylar
        .where(
          (detay) =>
              _sayi(detay['kalan_miktar']) > 0 &&
              _metin(detay['durum']).toUpperCase() != 'IPTAL',
        )
        .toList();

    if (secilebilirDetaylar.isEmpty) {
      _mesaj(
        'Bu siparişte sevk edilecek kalan ürün yok.',
        Colors.orange,
      );
      return;
    }

    final miktarControllerlari =
        <int, TextEditingController>{};

    for (final detay in secilebilirDetaylar) {
      final detayId = int.tryParse(
        detay['detay_id']?.toString() ?? '',
      );

      if (detayId != null) {
        miktarControllerlari[detayId] =
            TextEditingController(
          text: _sayi(
            detay['kalan_miktar'],
          ).toStringAsFixed(0),
        );
      }
    }

    final faturaNoController =
        TextEditingController();
    final belgeNoController =
        TextEditingController();

    String odemeTipi =
        _metin(siparis['odeme_tipi']) == '-'
            ? 'Veresiye'
            : _metin(siparis['odeme_tipi']);

    int? kasaId;

    final veresiyeBaslangic =
        odemeTipi.toLowerCase().trim() == 'veresiye' ||
        odemeTipi.toLowerCase().trim() == 'hesap';

    if (!veresiyeBaslangic && _kasalar.isNotEmpty) {
      kasaId = int.tryParse(
        _kasalar.first['kasa_id'].toString(),
      );
    }

    try {
      faturaNoController.text =
          await SupabaseService.yeniBelgeNoGetir(
        belgeTipi: 'SATIS',
      );
    } catch (e) { debugPrint('PRO ERP sessiz hata [$e]'); }

    if (!mounted) return;

    final sonuc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final veresiyeMi =
                odemeTipi.toLowerCase().trim() == 'veresiye' ||
                odemeTipi.toLowerCase().trim() == 'hesap';

            return AlertDialog(
              title: Text(
                'Siparişi Faturala - ${_metin(siparis['siparis_no'])}',
              ),
              content: MobilDialogIcerik(
                width: 820,
                height: 620,
                child: Column(
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 190,
                          child: TextField(
                            controller: faturaNoController,
                            decoration: const InputDecoration(
                              labelText: 'Fatura No',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 190,
                          child: TextField(
                            controller: belgeNoController,
                            decoration: const InputDecoration(
                              labelText: 'Belge No',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            value: [
                              'Veresiye',
                              'Nakit',
                              'Kredi Kartı',
                              'Havale',
                            ].contains(odemeTipi)
                                ? odemeTipi
                                : 'Veresiye',
                            decoration: const InputDecoration(
                              labelText: 'Ödeme Tipi',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Veresiye',
                                child: Text('Veresiye'),
                              ),
                              DropdownMenuItem(
                                value: 'Nakit',
                                child: Text('Nakit'),
                              ),
                              DropdownMenuItem(
                                value: 'Kredi Kartı',
                                child: Text('Kredi Kartı'),
                              ),
                              DropdownMenuItem(
                                value: 'Havale',
                                child: Text('Havale / EFT'),
                              ),
                            ],
                            onChanged: (deger) {
                              if (deger == null) return;

                              setDialogState(() {
                                odemeTipi = deger;

                                final yeniVeresiye =
                                    deger == 'Veresiye';

                                if (yeniVeresiye) {
                                  kasaId = null;
                                } else if (kasaId == null &&
                                    _kasalar.isNotEmpty) {
                                  kasaId = int.tryParse(
                                    _kasalar.first['kasa_id']
                                        .toString(),
                                  );
                                }
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 230,
                          child: DropdownButtonFormField<int>(
                            value: veresiyeMi ? null : kasaId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Kasa / Banka',
                              hintText: veresiyeMi
                                  ? 'Veresiyede kullanılmaz'
                                  : null,
                              border: const OutlineInputBorder(),
                            ),
                            items: _kasalar.map((kasa) {
                              return DropdownMenuItem<int>(
                                value: int.tryParse(
                                  kasa['kasa_id'].toString(),
                                ),
                                child: Text(
                                  kasa['kasa_adi']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: veresiyeMi
                                ? null
                                : (deger) {
                                    setDialogState(() {
                                      kasaId = deger;
                                    });
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'SEVK EDİLECEK MİKTARLAR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: secilebilirDetaylar.length,
                        separatorBuilder: (_, __) =>
                            const Divider(),
                        itemBuilder: (context, index) {
                          final detay =
                              secilebilirDetaylar[index];

                          final detayId = int.parse(
                            detay['detay_id'].toString(),
                          );

                          return ListTile(
                            title: Text(
                              _metin(detay['urun_adi']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${markaVeUreticiKodu(detay['marka'], detay['uretici_kodu'])} • '
                              'RAF: ${_metin(detay['raf'])}\n'
                              'Sipariş: ${_sayi(detay['miktar']).toStringAsFixed(0)} • '
                              'Sevk Edilen: ${_sayi(detay['sevk_edilen_miktar']).toStringAsFixed(0)} • '
                              'Kalan: ${_sayi(detay['kalan_miktar']).toStringAsFixed(0)} • '
                              'Stok: ${_sayi(detay['stok_miktari']).toStringAsFixed(0)}',
                            ),
                            trailing: SizedBox(
                              width: 130,
                              child: TextField(
                                controller:
                                    miktarControllerlari[detayId],
                                keyboardType:
                                    TextInputType.number,
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Sevk',
                                  border:
                                      OutlineInputBorder(),
                                ),
                              ),
                            ),
                          );
                        },
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
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final sevkler =
                        <Map<String, dynamic>>[];

                    for (final detay in secilebilirDetaylar) {
                      final detayId = int.parse(
                        detay['detay_id'].toString(),
                      );

                      final miktar = double.tryParse(
                            miktarControllerlari[detayId]
                                    ?.text
                                    .replaceAll(',', '.') ??
                                '0',
                          ) ??
                          0;

                      final kalan =
                          _sayi(detay['kalan_miktar']);

                      if (miktar < 0 || miktar > kalan) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              '${_metin(detay['urun_adi'])}: '
                              'Sevk miktarı 0 ile kalan miktar arasında olmalıdır.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (miktar > 0) {
                        sevkler.add({
                          'detay_id': detayId,
                          'miktar': miktar,
                        });
                      }
                    }

                    if (sevkler.isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'En az bir üründen sevk miktarı girin.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    if (!veresiyeMi && kasaId == null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Peşin satış için kasa seçin.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      {
                        'fatura_no':
                            faturaNoController.text.trim(),
                        'belge_no':
                            belgeNoController.text.trim(),
                        'odeme_tipi': odemeTipi,
                        'kasa_id':
                            veresiyeMi ? null : kasaId,
                        'sevkler': sevkler,
                      },
                    );
                  },
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Faturayı Oluştur'),
                ),
              ],
            );
          },
        );
      },
    );

    for (final controller in miktarControllerlari.values) {
      controller.dispose();
    }

    faturaNoController.dispose();
    belgeNoController.dispose();

    if (sonuc == null) return;

    setState(() {
      _islemYapiliyor = true;
    });

    try {
      final response = await SupabaseService.supabase.rpc(
        'satis_siparis_faturala',
        params: {
          'p_siparis_id': siparisId,
          'p_kasa_id': sonuc['kasa_id'],
          'p_odeme_tipi': sonuc['odeme_tipi'],
          'p_fatura_no': sonuc['fatura_no'],
          'p_belge_no': sonuc['belge_no'],
          'p_kullanici': YetkiService.aktifKullanici,
          'p_sevk_detaylari': sonuc['sevkler'],
        },
      );

      final satisId =
          int.tryParse(response?.toString() ?? '');

      if (satisId == null) {
        throw Exception(
          'Geçerli satış ID alınamadı.',
        );
      }

      if (!mounted) return;

      _mesaj(
        'Sipariş faturaya dönüştürüldü. Satış ID: $satisId',
        Colors.green,
      );

      await _verileriYukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj(
        'Sipariş faturalama hatası: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _islemYapiliyor = false;
        });
      }
    }
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: renk,
      ),
    );
  }

  Widget _siparisKarti(
    Map<String, dynamic> siparis,
  ) {
    final renk =
        _durumRengi(siparis['durum']);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: () {
          _detayGoster(siparis);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: MobilYatayRow(
            children: [
              CircleAvatar(
                backgroundColor:
                    renk.withOpacity(0.14),
                child: Icon(
                  Icons.assignment,
                  color: renk,
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 210,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metin(
                        siparis['siparis_no'],
                      ),
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tarih(siparis['tarih']),
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cariAdi(
                        siparis['cari_id'],
                      ),
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 18,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Depo: ${_depoAdi(siparis['depo_id'])}',
                        ),
                        Text(
                          'Termin: ${_metin(siparis['termin_tarihi'])}',
                        ),
                        Text(
                          'Kullanıcı: ${_metin(siparis['kullanici'])}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      _para(
                        siparis['genel_toplam'],
                      ),
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _metin(
                        siparis['durum'],
                      ),
                      style: TextStyle(
                        color: renk,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'SATIŞ SİPARİŞLERİ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          MobilAppBarActions(
            children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
            ),
            child: ElevatedButton.icon(
              onPressed: _yukleniyor
                  ? null
                  : _yeniKayitAc,
              icon: const Icon(Icons.add),
              label: const Text(
                'Yeni Satış Siparişi',
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _yukleniyor
                ? null
                : _verileriYukle,
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
            child: MobilYatayRow(
              minWidth: 760,
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        _aramaController,
                    decoration: InputDecoration(
                      hintText:
                          'Sipariş no, cari, depo, durum, açıklama...',
                      prefixIcon:
                          const Icon(Icons.search),
                      suffixIcon:
                          _aramaController
                                  .text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed:
                                      _aramaController
                                          .clear,
                                  icon: const Icon(
                                    Icons.clear,
                                  ),
                                ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 190,
                  child:
                      DropdownButtonFormField<
                          String>(
                    value: _durumFiltresi,
                    decoration:
                        const InputDecoration(
                      labelText: 'Durum',
                      border:
                          OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'TÜMÜ',
                        child:
                            Text('Tüm Durumlar'),
                      ),
                      DropdownMenuItem(
                        value:
                            'HAZIRLANIYOR',
                        child: Text(
                          'Hazırlanıyor',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ONAYLANDI',
                        child:
                            Text('Onaylandı'),
                      ),
                      DropdownMenuItem(
                        value: 'KISMI_SEVK',
                        child:
                            Text('Kısmi Sevk'),
                      ),
                      DropdownMenuItem(
                        value: 'TAMAMLANDI',
                        child:
                            Text('Tamamlandı'),
                      ),
                      DropdownMenuItem(
                        value: 'IPTAL',
                        child: Text('İptal'),
                      ),
                    ],
                    onChanged: (deger) {
                      if (deger == null) {
                        return;
                      }

                      setState(() {
                        _durumFiltresi =
                            deger;
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
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : _gorunenSiparisler.isEmpty
                    ? const Center(
                        child: Text(
                          'Sipariş bulunamadı.',
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh:
                            _verileriYukle,
                        child:
                            ListView.separated(
                          padding:
                              const EdgeInsets.all(
                            12,
                          ),
                          itemCount:
                              _gorunenSiparisler
                                  .length,
                          separatorBuilder:
                              (_, __) {
                            return const SizedBox(
                              height: 8,
                            );
                          },
                          itemBuilder:
                              (context, index) {
                            return _siparisKarti(
                              _gorunenSiparisler[
                                  index],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
