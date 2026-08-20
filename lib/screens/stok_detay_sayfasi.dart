// lib/screens/stok_detay_sayfasi.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stok_model.dart';
import '../services/supabase_service.dart';
import '../services/satis_taslak_service.dart';
import '../services/kurumsal_yazdirma_service.dart';

import 'widgets/stok_belge_detay_dialog.dart';
import 'satis_sayfasi.dart';

class StokDetaySayfasi extends StatefulWidget {
  final StokModel stok;

  const StokDetaySayfasi({
    super.key,
    required this.stok,
  });

  @override
  State<StokDetaySayfasi> createState() => _StokDetaySayfasiState();
}

class _StokDetaySayfasiState extends State<StokDetaySayfasi> {
  bool _yukleniyor = true;

  List<Map<String, dynamic>> _hareketler = [];

  double _toplamGiris = 0;
  double _toplamCikis = 0;
  double _toplamAlisTutari = 0;
  double _toplamSatisTutari = 0;

  Map<String, dynamic>? _sonAlis;
  Map<String, dynamic>? _sonSatis;

  double _normalStok = 0;
  double _iadeStok = 0;
  double _hasarliStok = 0;

  @override
  void initState() {
    super.initState();
    _hareketleriYukle();
  }

  int get _stokId => int.tryParse(widget.stok.id.toString()) ?? 0;

  Future<void> _hareketleriYukle() async {
    if (!mounted) return;

    setState(() => _yukleniyor = true);

    try {
      // Supabase query builder tipleri ile Future.wait generic
      // çıkarımı bazı Flutter/Dart sürümlerinde derleme hatası veriyor.
      // Bu nedenle sorguları ayrı ayrı await ediyoruz.
      final hareketResponse =
          await SupabaseService.supabase
              .from('stok_hareket')
              .select(
                'hareket_id, tarih, stok_id, islem_tipi, hareket_tipi, '
                'miktar, onceki_stok, sonraki_stok, belge_no, fatura_no, '
                'cari_id, depo_id, kullanici, aciklama, birim_maliyet, '
                'alis_ref, satis_ref',
              )
              .eq('stok_id', _stokId)
              .order('tarih', ascending: false);

      final cariResponse =
          await SupabaseService.supabase
              .from('cariler')
              .select('cari_id, unvan');

      final depoResponse =
          await SupabaseService.supabase
              .from('depolar')
              .select('depo_id, depo_adi');

      final depoDagilimi =
          await SupabaseService.stokDepoDagilimiGetir(
        _stokId,
      );

      final hareketler =
          List<Map<String, dynamic>>.from(
        hareketResponse,
      );

      final cariler =
          List<Map<String, dynamic>>.from(
        cariResponse,
      );

      final depolar =
          List<Map<String, dynamic>>.from(
        depoResponse,
      );

      final cariHaritasi = <int, String>{};
      final depoHaritasi = <int, String>{};

      for (final cari in cariler) {
        final id = int.tryParse(cari['cari_id']?.toString() ?? '');
        if (id != null) {
          cariHaritasi[id] = cari['unvan']?.toString() ?? '';
        }
      }

      for (final depo in depolar) {
        final id = int.tryParse(depo['depo_id']?.toString() ?? '');
        if (id != null) {
          depoHaritasi[id] = depo['depo_adi']?.toString() ?? '';
        }
      }

      double toplamGiris = 0;
      double toplamCikis = 0;
      double toplamAlisTutari = 0;
      double toplamSatisTutari = 0;

      Map<String, dynamic>? sonAlis;
      Map<String, dynamic>? sonSatis;

      for (final hareket in hareketler) {
        final cariId =
            int.tryParse(hareket['cari_id']?.toString() ?? '');
        final depoId =
            int.tryParse(hareket['depo_id']?.toString() ?? '');

        hareket['cari_unvan'] =
            cariId == null ? '-' : (cariHaritasi[cariId] ?? '-');
        hareket['depo_adi'] =
            depoId == null ? '-' : (depoHaritasi[depoId] ?? '-');

        final miktar = _sayi(hareket['miktar']);
        final maliyet = _sayi(hareket['birim_maliyet']);
        final girisMi = _girisMi(hareket);
        final islem = _metin(hareket['islem_tipi']).toUpperCase();

        if (girisMi) {
          toplamGiris += miktar;
        } else {
          toplamCikis += miktar;
        }

        if ((islem == 'ALIS' || islem == 'ALIŞ') && sonAlis == null) {
          sonAlis = hareket;
        }

        if ((islem == 'SATIS' || islem == 'SATIŞ') && sonSatis == null) {
          sonSatis = hareket;
        }

        if (islem == 'ALIS' || islem == 'ALIŞ') {
          toplamAlisTutari += miktar * maliyet;
        }

        if (islem == 'SATIS' || islem == 'SATIŞ') {
          toplamSatisTutari += miktar * widget.stok.satisFiyatiPerakende;
        }
      }

      if (!mounted) return;

      setState(() {
        _hareketler = hareketler;
        _toplamGiris = toplamGiris;
        _toplamCikis = toplamCikis;
        _toplamAlisTutari = toplamAlisTutari;
        _toplamSatisTutari = toplamSatisTutari;
        _sonAlis = sonAlis;
        _sonSatis = sonSatis;
        _normalStok = _sayi(depoDagilimi['normal']);
        _iadeStok = _sayi(depoDagilimi['iade']);
        _hasarliStok = _sayi(depoDagilimi['hasarli']);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _yukleniyor = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok hareketleri yüklenemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  bool _girisMi(Map<String, dynamic> hareket) {
    final hareketTipi =
        _metin(hareket['hareket_tipi']).toUpperCase();

    if (hareketTipi == 'GIRIS' || hareketTipi == 'GİRİŞ') {
      return true;
    }

    if (hareketTipi == 'CIKIS' || hareketTipi == 'ÇIKIŞ') {
      return false;
    }

    final islem = _metin(hareket['islem_tipi']).toUpperCase();

    if (islem.contains('IPTAL') || islem.contains('İPTAL')) {
      // Satış iptali stoğa giriş, alış iptali stoktan çıkıştır.
      return islem.startsWith('SATIS') || islem.startsWith('SATIŞ');
    }

    return islem.startsWith('ALIS') ||
        islem.startsWith('ALIŞ');
  }

  Color _hareketRengi(Map<String, dynamic> hareket) {
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

    return _girisMi(hareket)
        ? Colors.green.shade700
        : Colors.red.shade700;
  }

  Widget _bilgiKutusu(
    String baslik,
    String deger, {
    IconData? ikon,
    Color? renk,
  }) {
    return Container(
      width: 205,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (ikon != null) ...[
            Icon(ikon, color: renk ?? Colors.blueGrey),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  deger,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: renk,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sonHareketKarti({
    required String baslik,
    required Map<String, dynamic>? hareket,
    required IconData ikon,
    required Color renk,
  }) {
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hareket == null
              ? null
              : () {
                  StokBelgeDetayDialog.ac(
                    context,
                    hareket,
                  );
                },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: renk.withOpacity(0.14),
                child: Icon(ikon, color: renk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: hareket == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            baslik,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('Hareket bulunamadı.'),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            baslik,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(_tarih(hareket['tarih'])),
                          Text(
                            'Cari: ${_metin(hareket['cari_unvan'])}',
                          ),
                          Text(
                            'Miktar: ${_sayi(hareket['miktar']).toStringAsFixed(0)}',
                          ),
                          Text(
                            'Belge: ${_metin(hareket['belge_no'])}',
                          ),
                        ],
                      ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _panoyaKopyala(
    String metin, {
    String mesaj = 'Panoya kopyalandı',
  }) {
    Clipboard.setData(
      ClipboardData(text: metin),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        duration: const Duration(
          milliseconds: 900,
        ),
      ),
    );
  }

  String _tumStokBilgileriMetni() {
    final satirlar = <String>[
      'Ürün Adı: ${_metin(widget.stok.urunAdi)}',
      'Marka: ${_metin(widget.stok.marka)}',
      'Model: ${_metin(widget.stok.model)}',
      'Araç: ${_metin(widget.stok.arac)}',
      'Ürün Özelliği: ${_metin(widget.stok.urunOzellik)}',
      'Üretici Kodu: ${_metin(widget.stok.ureticiKodu)}',
      'OEM: ${_metin(widget.stok.oemNo)}',
      'Cross Kod: ${_metin(widget.stok.cross)}',
      'Rakip Kod: ${_metin(widget.stok.rakipKod)}',
      'Barkod: ${_metin(widget.stok.barkod)}',
      'RAF: ${_metin(widget.stok.raf)}',
    ];

    return satirlar.join('\n');
  }

  Widget _kopyalanabilirBilgiSatiri({
    required String baslik,
    required String deger,
    required IconData ikon,
  }) {
    final temizDeger = _metin(deger);

    return Container(
      constraints: const BoxConstraints(
        minWidth: 280,
        maxWidth: 560,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            ikon,
            size: 19,
            color: Colors.blueGrey.shade700,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  temizDeger,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '$baslik kopyala',
            visualDensity: VisualDensity.compact,
            onPressed: temizDeger == '-'
                ? null
                : () {
                    _panoyaKopyala(
                      temizDeger,
                      mesaj:
                          '$baslik panoya kopyalandı',
                    );
                  },
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kodVeAciklamaBolumu() {
    return Card(
      margin: const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                ),
                const SizedBox(width: 8),
                const Text(
                  'PARÇA KODLARI VE AÇIKLAMALAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    _panoyaKopyala(
                      _tumStokBilgileriMetni(),
                      mesaj:
                          'Tüm parça bilgileri panoya kopyalandı',
                    );
                  },
                  icon: const Icon(
                    Icons.copy_all_rounded,
                  ),
                  label: const Text(
                    'Tümünü Kopyala',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _kopyalanabilirBilgiSatiri(
                  baslik: 'Üretici Kodu',
                  deger: widget.stok.ureticiKodu,
                  ikon: Icons.qr_code_rounded,
                ),
                _kopyalanabilirBilgiSatiri(
                  baslik: 'OEM Kodları',
                  deger: widget.stok.oemNo,
                  ikon: Icons.numbers_rounded,
                ),
                _kopyalanabilirBilgiSatiri(
                  baslik: 'Cross Kodlar',
                  deger: widget.stok.cross,
                  ikon: Icons.compare_arrows_rounded,
                ),
                _kopyalanabilirBilgiSatiri(
                  baslik: 'Rakip Kodlar',
                  deger: widget.stok.rakipKod,
                  ikon: Icons.swap_horiz_rounded,
                ),
                _kopyalanabilirBilgiSatiri(
                  baslik: 'Model',
                  deger: widget.stok.model,
                  ikon: Icons.category_outlined,
                ),
                _kopyalanabilirBilgiSatiri(
                  baslik: 'Araç',
                  deger: widget.stok.arac,
                  ikon: Icons.directions_car_outlined,
                ),
                _kopyalanabilirBilgiSatiri(
                  baslik: 'Ürün Özelliği',
                  deger: widget.stok.urunOzellik,
                  ikon: Icons.description_outlined,
                ),
                _kopyalanabilirBilgiSatiri(
                  baslik: 'Barkod',
                  deger: widget.stok.barkod,
                  ikon: Icons.barcode_reader,
                ),
                _kopyalanabilirBilgiSatiri(
                  baslik: 'RAF',
                  deger: widget.stok.raf,
                  ikon: Icons.shelves,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resmiBuyut(String url) {
    if (url.trim().isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              SizedBox(
                width: MediaQuery.of(dialogContext).size.width * 0.96,
                height: MediaQuery.of(dialogContext).size.height * 0.92,
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 6,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'Resim yüklenemedi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ustBilgiler() {
    final stokRengi =
        _normalStok <= 2 ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: widget.stok.resim.isEmpty
                      ? const Icon(
                          Icons.inventory_2,
                          size: 44,
                          color: Colors.blue,
                        )
                      : GestureDetector(
                          onTap: () => _resmiBuyut(widget.stok.resim),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                widget.stok.resim,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.inventory_2,
                                  size: 44,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stok.urunAdi,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Marka: ${_metin(widget.stok.marka)}'),
                      Text('Model: ${_metin(widget.stok.model)}'),
                      Text('Araç: ${_metin(widget.stok.arac)}'),
                      Text(
                        'Ürün Özelliği: ${_metin(widget.stok.urunOzellik)}',
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'MEVCUT STOK',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _normalStok.toStringAsFixed(_normalStok == _normalStok.roundToDouble() ? 0 : 2),
                      style: TextStyle(
                        color: stokRengi,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _bilgiKutusu(
                  'Üretici Kodu',
                  _metin(widget.stok.ureticiKodu),
                  ikon: Icons.qr_code,
                ),
                _bilgiKutusu(
                  'RAF',
                  _metin(widget.stok.raf),
                  ikon: Icons.shelves,
                ),
                _bilgiKutusu(
                  'Barkod',
                  _metin(widget.stok.barkod),
                  ikon: Icons.barcode_reader,
                ),
                _bilgiKutusu(
                  'Alış Fiyatı',
                  _para(widget.stok.alisFiyati),
                  ikon: Icons.shopping_cart,
                  renk: Colors.orange.shade800,
                ),
                _bilgiKutusu(
                  'Perakende',
                  _para(widget.stok.satisFiyatiPerakende),
                  ikon: Icons.point_of_sale,
                  renk: Colors.green.shade700,
                ),
                _bilgiKutusu(
                  'Toptan',
                  _para(widget.stok.satisFiyatiToptan),
                  ikon: Icons.store,
                  renk: Colors.blue.shade700,
                ),
                _bilgiKutusu(
                  'İade Deposu',
                  _normalStok == -999 ? '-' : _iadeStok.toStringAsFixed(_iadeStok == _iadeStok.roundToDouble() ? 0 : 2),
                  ikon: Icons.assignment_return_rounded,
                  renk: Colors.orange.shade800,
                ),
                _bilgiKutusu(
                  'Hasarlı Depo',
                  _hasarliStok.toStringAsFixed(_hasarliStok == _hasarliStok.roundToDouble() ? 0 : 2),
                  ikon: Icons.warning_amber_rounded,
                  renk: Colors.red.shade800,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ozetler() {
    final tahminiKar = _toplamSatisTutari - _toplamAlisTutari;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _bilgiKutusu(
            'Toplam Giriş',
            _toplamGiris.toStringAsFixed(0),
            ikon: Icons.south_west,
            renk: Colors.green.shade700,
          ),
          _bilgiKutusu(
            'Toplam Çıkış',
            _toplamCikis.toStringAsFixed(0),
            ikon: Icons.north_east,
            renk: Colors.red.shade700,
          ),
          _bilgiKutusu(
            'Alış Tutarı',
            _para(_toplamAlisTutari),
            ikon: Icons.shopping_cart,
            renk: Colors.green.shade700,
          ),
          _bilgiKutusu(
            'Satış Tutarı',
            _para(_toplamSatisTutari),
            ikon: Icons.payments,
            renk: Colors.red.shade700,
          ),
          _bilgiKutusu(
            'Tahmini Kâr',
            _para(tahminiKar),
            ikon: Icons.trending_up,
            renk: tahminiKar >= 0
                ? Colors.teal.shade700
                : Colors.red.shade700,
          ),
        ],
      ),
    );
  }

  Widget _hareketListesi() {
    if (_hareketler.isEmpty) {
      return const Center(
        child: Text(
          'Bu ürüne ait stok hareketi bulunamadı.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _hareketler.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final hareket = _hareketler[index];
        final girisMi = _girisMi(hareket);
        final renk = _hareketRengi(hareket);

        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              StokBelgeDetayDialog.ac(
                context,
                hareket,
              );
            },
            child: ListTile(
              leading: CircleAvatar(
              backgroundColor: renk.withOpacity(0.14),
              child: Icon(
                girisMi ? Icons.south_west : Icons.north_east,
                color: renk,
              ),
            ),
            title: Text(
              _metin(hareket['islem_tipi']),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Tarih: ${_tarih(hareket['tarih'])}\n'
              'Belge: ${_metin(hareket['belge_no'])} • '
              'Cari: ${_metin(hareket['cari_unvan'])}\n'
              'Depo: ${_metin(hareket['depo_adi'])} • '
              'Kullanıcı: ${_metin(hareket['kullanici'])}',
            ),
            trailing: SizedBox(
              width: 210,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _miniDeger(
                    girisMi ? 'Giriş' : 'Çıkış',
                    '${girisMi ? '+' : '-'}'
                        '${_sayi(hareket['miktar']).toStringAsFixed(0)}',
                    renk,
                  ),
                  const SizedBox(width: 12),
                  _miniDeger(
                    'Kalan',
                    _metin(hareket['sonraki_stok']),
                    Colors.blueGrey,
                  ),
                ],
              ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniDeger(String baslik, String deger, Color renk) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          baslik,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
        Text(
          deger,
          style: TextStyle(
            color: renk,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'STOK KARTI VE HAREKETLERİ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _hareketleriYukle,
            icon: const Icon(Icons.refresh),
          ),
          ElevatedButton.icon(
            onPressed: _normalStok <= 0
                ? null
                : () async {
                    SatisTaslakService.ekle(widget.stok);
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SatisSayfasi(),
                      ),
                    );

                    if (!mounted) return;
                    await _hareketleriYukle();
                  },
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Satışa Ekle'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await KurumsalYazdirmaService.stokKartiYazdir(widget.stok);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Stok kartı yazdırılamadı: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.print),
            label: const Text('Yazdır'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _ustBilgiler(),
                          _kodVeAciklamaBolumu(),
                          _ozetler(),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: LayoutBuilder(
                              builder: (context, cardConstraints) {
                                if (cardConstraints.maxWidth < 760) {
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          _sonHareketKarti(
                                            baslik: 'Son Alış',
                                            hareket: _sonAlis,
                                            ikon: Icons.shopping_cart,
                                            renk: Colors.green.shade700,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          _sonHareketKarti(
                                            baslik: 'Son Satış',
                                            hareket: _sonSatis,
                                            ikon: Icons.point_of_sale,
                                            renk: Colors.red.shade700,
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    _sonHareketKarti(
                                      baslik: 'Son Alış',
                                      hareket: _sonAlis,
                                      ikon: Icons.shopping_cart,
                                      renk: Colors.orange.shade800,
                                    ),
                                    const SizedBox(width: 10),
                                    _sonHareketKarti(
                                      baslik: 'Son Satış',
                                      hareket: _sonSatis,
                                      ikon: Icons.point_of_sale,
                                      renk: Colors.green.shade700,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'STOK HAREKETLERİ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: constraints.maxHeight * 0.55,
                            child: _hareketListesi(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}