import 'dart:async';

// lib/screens/stok_hareketleri_sayfasi.dart

import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import '../services/supabase_service.dart';
import '../utils/marka_kod.dart';

import 'widgets/stok_belge_detay_dialog.dart';

class StokHareketleriSayfasi extends StatefulWidget {
  const StokHareketleriSayfasi({super.key});

  @override
  State<StokHareketleriSayfasi> createState() => _StokHareketleriSayfasiState();
}

class _StokHareketleriSayfasiState extends State<StokHareketleriSayfasi> {
  final TextEditingController _aramaController = TextEditingController();
  Timer? _aramaDebounce;

  bool _yukleniyor = true;

  String _islemFiltresi = 'TÜMÜ';

  List<Map<String, dynamic>> _tumHareketler = [];
  List<Map<String, dynamic>> _gorunenHareketler = [];

  @override
  void initState() {
    super.initState();
    _aramaController.addListener(_filtreyiZamanla);
    _hareketleriYukle();
  }

  @override
  void dispose() {
    _aramaDebounce?.cancel();
    _aramaController.dispose();
    super.dispose();
  }

  void _filtreyiZamanla() {
    _aramaDebounce?.cancel();
    _aramaDebounce = Timer(
      const Duration(milliseconds: 220),
      _filtrele,
    );
  }

  Future<void> _hareketleriYukle() async {
    if (!mounted) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      // Önce hareketleri alıyoruz. Sonra yalnız bu hareketlerde kullanılan
      // stok/cari/depo kartlarını çekiyoruz. Böylece stok kartı sayısı
      // büyüdüğünde bütün master tabloları her açılışta indirmiyoruz.
      final hareketResponse = await SupabaseService.supabase
          .from('stok_hareket')
          .select(
            'hareket_id, tarih, kullanici, stok_id, islem_tipi, '
            'miktar, belge_no, aciklama, depo_id, cari_id, '
            'alis_ref, satis_ref, fatura_no, onceki_stok, '
            'sonraki_stok, birim_maliyet, hareket_tipi',
          )
          .order('tarih', ascending: false);

      final hareketler =
          List<Map<String, dynamic>>.from(hareketResponse as List);

      final stokIdleri = hareketler
          .map((e) => int.tryParse(e['stok_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet()
          .toList(growable: false);
      final cariIdleri = hareketler
          .map((e) => int.tryParse(e['cari_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet()
          .toList(growable: false);
      final depoIdleri = hareketler
          .map((e) => int.tryParse(e['depo_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet()
          .toList(growable: false);

      Future<List<Map<String, dynamic>>> parcaliGetir({
        required String tablo,
        required String idKolonu,
        required String select,
        required List<int> idler,
      }) async {
        if (idler.isEmpty) return <Map<String, dynamic>>[];

        final sonuc = <Map<String, dynamic>>[];
        const parcaBoyutu = 200;

        for (var i = 0; i < idler.length; i += parcaBoyutu) {
          final son = (i + parcaBoyutu < idler.length)
              ? i + parcaBoyutu
              : idler.length;
          final parca = idler.sublist(i, son);

          final raw = await SupabaseService.supabase
              .from(tablo)
              .select(select)
              .inFilter(idKolonu, parca);

          sonuc.addAll(List<Map<String, dynamic>>.from(raw as List));
        }

        return sonuc;
      }

      final metadata = await Future.wait([
        parcaliGetir(
          tablo: 'stoklar',
          idKolonu: 'stok_id',
          select: 'stok_id, urun_adi, uretici_kodu, raf, marka',
          idler: stokIdleri,
        ),
        parcaliGetir(
          tablo: 'cariler',
          idKolonu: 'cari_id',
          select: 'cari_id, unvan',
          idler: cariIdleri,
        ),
        parcaliGetir(
          tablo: 'depolar',
          idKolonu: 'depo_id',
          select: 'depo_id, depo_adi',
          idler: depoIdleri,
        ),
      ]);

      final stoklar = metadata[0];
      final cariler = metadata[1];
      final depolar = metadata[2];

      final stokHaritasi = <int, Map<String, dynamic>>{};
      final cariHaritasi = <int, String>{};
      final depoHaritasi = <int, String>{};

      for (final stok in stoklar) {
        final stokId = int.tryParse(stok['stok_id']?.toString() ?? '');
        if (stokId != null) {
          stokHaritasi[stokId] = stok;
        }
      }

      for (final cari in cariler) {
        final cariId = int.tryParse(cari['cari_id']?.toString() ?? '');
        if (cariId != null) {
          cariHaritasi[cariId] = cari['unvan']?.toString() ?? '';
        }
      }

      for (final depo in depolar) {
        final depoId = int.tryParse(depo['depo_id']?.toString() ?? '');
        if (depoId != null) {
          depoHaritasi[depoId] = depo['depo_adi']?.toString() ?? '';
        }
      }

      for (final hareket in hareketler) {
        final stokId = int.tryParse(hareket['stok_id']?.toString() ?? '');
        final cariId = int.tryParse(hareket['cari_id']?.toString() ?? '');
        final depoId = int.tryParse(hareket['depo_id']?.toString() ?? '');

        final stok = stokId == null ? null : stokHaritasi[stokId];

        hareket['urun_adi'] = stok?['urun_adi']?.toString() ?? '-';
        hareket['uretici_kodu'] =
            stok?['uretici_kodu']?.toString() ?? '-';
        hareket['raf'] = stok?['raf']?.toString() ?? '-';
        hareket['marka'] = stok?['marka']?.toString() ?? '-';
        hareket['cari_unvan'] =
            cariId == null ? '-' : (cariHaritasi[cariId] ?? '-');
        hareket['depo_adi'] =
            depoId == null ? '-' : (depoHaritasi[depoId] ?? '-');
      }

      if (!mounted) return;

      setState(() {
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

      _mesaj('Stok hareketleri yüklenemedi: $e', Colors.red);
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
        final islemTipi = _metin(hareket['islem_tipi']).toUpperCase();

        final filtreUyuyor =
            _islemFiltresi == 'TÜMÜ' ||
            (_islemFiltresi == 'ALIŞ' &&
                (islemTipi.startsWith('ALIS') ||
                    islemTipi.startsWith('ALIŞ'))) ||
            (_islemFiltresi == 'SATIŞ' &&
                (islemTipi.startsWith('SATIS') ||
                    islemTipi.startsWith('SATIŞ'))) ||
            (_islemFiltresi == 'İPTAL' &&
                (islemTipi.contains('IPTAL') || islemTipi.contains('İPTAL')));

        if (!filtreUyuyor) return false;

        if (kelimeler.isEmpty) return true;

        final metin = [
          hareket['hareket_id'],
          hareket['urun_adi'],
          hareket['uretici_kodu'],
          hareket['raf'],
          hareket['marka'],
          hareket['islem_tipi'],
          hareket['hareket_tipi'],
          hareket['belge_no'],
          hareket['fatura_no'],
          hareket['cari_unvan'],
          hareket['depo_adi'],
          hareket['kullanici'],
          hareket['aciklama'],
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

  bool _girisMi(Map<String, dynamic> hareket) {
    final hareketTipi = _metin(hareket['hareket_tipi']).toUpperCase();

    if (hareketTipi == 'GIRIS' || hareketTipi == 'GİRİŞ') return true;
    if (hareketTipi == 'CIKIS' || hareketTipi == 'ÇIKIŞ') return false;

    final islem = _metin(hareket['islem_tipi']).toUpperCase();

    if (islem.contains('IPTAL') || islem.contains('İPTAL')) {
      return islem.startsWith('SATIS') || islem.startsWith('SATIŞ');
    }

    return islem.startsWith('ALIS') || islem.startsWith('ALIŞ');
  }

  Color _islemRengi(Map<String, dynamic> hareket) {
    final islem = _metin(hareket['islem_tipi']).toUpperCase();

    if (islem.contains('IPTAL') || islem.contains('İPTAL')) {
      return Colors.orange.shade800;
    }

    if (islem.startsWith('ALIS') || islem.startsWith('ALIŞ')) {
      return Colors.green.shade700;
    }

    if (islem.startsWith('SATIS') || islem.startsWith('SATIŞ')) {
      return Colors.red.shade700;
    }

    return _girisMi(hareket) ? Colors.green.shade700 : Colors.red.shade700;
  }

  IconData _islemIkonu(Map<String, dynamic> hareket) {
    final islemTipi = _metin(hareket['islem_tipi']).toUpperCase();

    if (islemTipi.contains('IPTAL') || islemTipi.contains('İPTAL')) {
      return Icons.undo;
    }

    return _girisMi(hareket) ? Icons.south_west : Icons.north_east;
  }

  String _miktarMetni(Map<String, dynamic> hareket) {
    final miktar = _sayi(hareket['miktar']);
    final isaret = _girisMi(hareket) ? '+' : '-';

    return '$isaret${miktar.toStringAsFixed(0)}';
  }

  String _islemAdi(Map<String, dynamic> hareket) {
    final islem = _metin(hareket['islem_tipi']).toUpperCase();

    if (islem == 'KONSINYE_CIKIS' || islem == 'KONSİNYE_ÇIKIŞ') {
      return 'Konsinye Çıkış';
    }

    if (islem == 'KONSINYE_GIRIS' || islem == 'KONSİNYE_GİRİŞ') {
      return 'Konsinye Giriş';
    }

    if (islem == 'TRANSFER_CIKIS' || islem == 'TRANSFER_ÇIKIŞ') {
      return 'Transfer Çıkış';
    }

    if (islem == 'TRANSFER_GIRIS' || islem == 'TRANSFER_GİRİŞ') {
      return 'Transfer Giriş';
    }

    if (islem == 'SATIS_IRSALIYE' ||
        islem == 'SATIŞ_IRSALIYE' ||
        islem == 'SATIS_İRSALİYE' ||
        islem == 'SATIŞ_İRSALİYE') {
      return 'Satış İrsaliyesi';
    }

    if (islem == 'ALIS_IRSALIYE' ||
        islem == 'ALIŞ_IRSALIYE' ||
        islem == 'ALIS_İRSALİYE' ||
        islem == 'ALIŞ_İRSALİYE') {
      return 'Alış İrsaliyesi';
    }

    if (islem == 'SATIS' || islem == 'SATIŞ') {
      return 'Satış';
    }

    if (islem == 'ALIS' || islem == 'ALIŞ') {
      return 'Alış';
    }

    if (islem.contains('SATIS_IPTAL') || islem.contains('SATIŞ_IPTAL')) {
      return 'Satış İptal';
    }

    if (islem.contains('ALIS_IPTAL') || islem.contains('ALIŞ_IPTAL')) {
      return 'Alış İptal';
    }

    return _metin(hareket['islem_tipi']).replaceAll('_', ' ');
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  void _detayGoster(Map<String, dynamic> hareket) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(_islemIkonu(hareket), color: _islemRengi(hareket)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Stok Hareket Detayı')),
            ],
          ),
          content: MobilDialogIcerik(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detaySatiri('Ürün', _metin(hareket['urun_adi'])),
                  _detaySatiri(
                    'Kod',
                    markaVeUreticiKodu(
                      hareket['marka'],
                      hareket['uretici_kodu'],
                    ),
                  ),
                  _detaySatiri('RAF', _metin(hareket['raf'])),
                  _detaySatiri('İşlem Tipi', _metin(hareket['islem_tipi'])),
                  _detaySatiri('Hareket Tipi', _metin(hareket['hareket_tipi'])),
                  _detaySatiri(
                    'Miktar',
                    _miktarMetni(hareket),
                    renk: _islemRengi(hareket),
                    kalin: true,
                  ),
                  _detaySatiri('Önceki Stok', _metin(hareket['onceki_stok'])),
                  _detaySatiri('Sonraki Stok', _metin(hareket['sonraki_stok'])),
                  _detaySatiri(
                    'Birim Maliyet',
                    _para(hareket['birim_maliyet']),
                  ),
                  const Divider(height: 24),
                  _detaySatiri('Fatura No', _metin(hareket['fatura_no'])),
                  _detaySatiri('Belge No', _metin(hareket['belge_no'])),
                  _detaySatiri('Cari', _metin(hareket['cari_unvan'])),
                  _detaySatiri('Depo', _metin(hareket['depo_adi'])),
                  _detaySatiri('Kullanıcı', _metin(hareket['kullanici'])),
                  _detaySatiri('Tarih', _tarih(hareket['tarih'])),
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

  Widget _detaySatiri(
    String baslik,
    String deger, {
    Color? renk,
    bool kalin = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(baslik, style: const TextStyle(color: Colors.grey)),
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

    final faturaNo = _metin(hareket['fatura_no']);
    final belgeNo = _metin(hareket['belge_no']);

    final gosterilecekBelge = faturaNo != '-' ? faturaNo : belgeNo;

    if (MobilUyum.telefon(context)) {
      return _mobilHareketKarti(hareket, renk, gosterilecekBelge);
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.8,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          StokBelgeDetayDialog.ac(context, hareket);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: renk.withOpacity(0.12),
                child: Icon(_islemIkonu(hareket), color: renk, size: 21),
              ),
              const SizedBox(width: 14),

              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metin(hareket['urun_adi']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.24),
                            ),
                          ),
                          child: Text(
                            markaVeUreticiKodu(
                              hareket['marka'],
                              hareket['uretici_kodu'],
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          'Cari: ${_metin(hareket['cari_unvan'])}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 18),

              SizedBox(
                width: 145,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _islemAdi(hareket),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: renk,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tarih(hareket['tarih']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: 100,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _miktarMetni(hareket),
                    style: TextStyle(
                      color: renk,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 18),

              SizedBox(
                width: 165,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gosterilecekBelge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _metin(hareket['depo_adi']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Belge Detayı',
                onPressed: () {
                  StokBelgeDetayDialog.ac(context, hareket);
                },
                icon: const Icon(Icons.visibility_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobilHareketKarti(
    Map<String, dynamic> hareket,
    Color renk,
    String gosterilecekBelge,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.8,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => StokBelgeDetayDialog.ac(context, hareket),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: renk.withOpacity(0.12),
                    child: Icon(_islemIkonu(hareket), color: renk, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _metin(hareket['urun_adi']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          markaVeUreticiKodu(
                            hareket['marka'],
                            hareket['uretici_kodu'],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _islemAdi(hareket),
                          style: TextStyle(
                            color: renk,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _miktarMetni(hareket),
                    style: TextStyle(
                      color: renk,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Cari: ${_metin(hareket['cari_unvan'])}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Text(
                'Belge: $gosterilecekBelge',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade800),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Depo: ${_metin(hareket['depo_adi'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Text(
                    _tarih(hareket['tarih']),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aramaAlani() {
    return TextField(
      controller: _aramaController,
      decoration: InputDecoration(
        hintText: 'Ürün, kod, RAF, cari, fatura no...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _aramaController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Temizle',
                onPressed: _aramaController.clear,
                icon: const Icon(Icons.clear),
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _islemFiltreAlani() {
    return DropdownButtonFormField<String>(
      value: _islemFiltresi,
      decoration: const InputDecoration(
        labelText: 'İşlem',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'TÜMÜ', child: Text('Tüm Hareketler')),
        DropdownMenuItem(value: 'ALIŞ', child: Text('Alış')),
        DropdownMenuItem(value: 'SATIŞ', child: Text('Satış')),
        DropdownMenuItem(value: 'İPTAL', child: Text('İptaller')),
      ],
      onChanged: (deger) {
        if (deger == null) return;
        setState(() => _islemFiltresi = deger);
        _filtrele();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MobilUyum.telefon(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'STOK HAREKETLERİ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _hareketleriYukle,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: mobil
                ? Column(
                    children: [
                      _aramaAlani(),
                      const SizedBox(height: 10),
                      _islemFiltreAlani(),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _aramaAlani()),
                      const SizedBox(width: 12),
                      SizedBox(width: 170, child: _islemFiltreAlani()),
                    ],
                  ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _gorunenHareketler.isEmpty
                ? const Center(
                    child: Text(
                      'Stok hareketi bulunamadı.',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _hareketleriYukle,
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
