// lib/screens/raporlar_sayfasi.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import '../services/supabase_service.dart';

class RaporlarSayfasi extends StatefulWidget {
  final int baslangicSekmesi;
  const RaporlarSayfasi({super.key, this.baslangicSekmesi = 0});

  @override
  State<RaporlarSayfasi> createState() => _RaporlarSayfasiState();
}

class _RaporlarSayfasiState extends State<RaporlarSayfasi>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _yukleniyor = true;
  bool _tamVeriYuklendi = false;

  DateTime _baslangic = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _bitis = DateTime.now();

  final TextEditingController _aramaController = TextEditingController();

  int? _secilenCariId;
  String? _secilenKullanici;
  String _durumFiltresi = 'TÜMÜ';

  List<Map<String, dynamic>> _cariler = [];
  List<Map<String, dynamic>> _satislar = [];
  List<Map<String, dynamic>> _alislar = [];
  List<Map<String, dynamic>> _stoklar = [];
  List<Map<String, dynamic>> _cariHareketler = [];
  List<Map<String, dynamic>> _tumCariHareketler = [];
  List<Map<String, dynamic>> _kasaHareketler = [];
  List<Map<String, dynamic>> _tumKasaHareketler = [];
  List<Map<String, dynamic>> _satisDetaylar = [];
  List<Map<String, dynamic>> _alisDetaylar = [];
  List<Map<String, dynamic>> _kasalar = [];
  List<Map<String, dynamic>> _giderler = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.baslangicSekmesi < 0 ? 0 : (widget.baslangicSekmesi > 5 ? 5 : widget.baslangicSekmesi),
    );

    _aramaController.addListener(() {
      if (mounted) setState(() {});
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index != 2 && !_tamVeriYuklendi) {
        _verileriYukle();
      }
    });

    if (_tabController.index == 2) {
      _stokVerileriniHizliYukle();
    } else {
      _verileriYukle();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aramaController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _detaylariIdlerleGetir({
    required String tablo,
    required String idKolonu,
    required List<int> ids,
    required String kolonlar,
  }) async {
    if (ids.isEmpty) return <Map<String, dynamic>>[];

    // Çok fazla ID'yi tek URL'e koymak PostgREST isteğini gereksiz büyütür.
    // Küçük parçalar halinde paralel getiriyoruz.
    const parcaBoyutu = 150;
    final istekler = <Future<dynamic>>[];
    for (var i = 0; i < ids.length; i += parcaBoyutu) {
      final son = (i + parcaBoyutu < ids.length) ? i + parcaBoyutu : ids.length;
      istekler.add(
        SupabaseService.supabase
            .from(tablo)
            .select(kolonlar)
            .inFilter(idKolonu, ids.sublist(i, son)),
      );
    }

    final cevaplar = await Future.wait(istekler);
    final sonuc = <Map<String, dynamic>>[];
    for (final cevap in cevaplar) {
      sonuc.addAll(List<Map<String, dynamic>>.from(cevap as List));
    }
    return sonuc;
  }

  Future<void> _stokVerileriniHizliYukle() async {
    if (!mounted) return;
    setState(() => _yukleniyor = true);

    try {
      final baslangicIso = DateTime(
        _baslangic.year,
        _baslangic.month,
        _baslangic.day,
      ).toUtc().toIso8601String();
      final bitisIso = DateTime(
        _bitis.year,
        _bitis.month,
        _bitis.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      // İlk ekranda yalnız gerçekten gerekli üç veri setini alıyoruz.
      // Eski sürüm satış/alış detay tablolarının TAMAMINI burada çekiyordu.
      final ilk = await Future.wait([
        SupabaseService.supabase
            .from('stoklar')
            .select(
              'stok_id, urun_adi, uretici_kodu, oem_no, marka, model, '
              'stok_miktari, alis_fiyati, satis_fiyati_perakende, '
              'satis_fiyati_toptan, raf',
            )
            .order('urun_adi'),
        SupabaseService.supabase
            .from('satis_baslik')
            .select('satis_id, tarih, durum')
            .gte('tarih', baslangicIso)
            .lte('tarih', bitisIso),
        SupabaseService.supabase
            .from('alis_baslik')
            .select('alis_id, tarih, durum')
            .gte('tarih', baslangicIso)
            .lte('tarih', bitisIso),
      ]);

      if (!mounted) return;

      final stoklar = List<Map<String, dynamic>>.from(ilk[0] as List);
      final satislar = List<Map<String, dynamic>>.from(ilk[1] as List);
      final alislar = List<Map<String, dynamic>>.from(ilk[2] as List);

      // Kullanıcı stok listesini hemen görsün. Özet detaylar birkaç milisaniye
      // sonra gelir; tam ekran spinner gereksiz yere beklemez.
      setState(() {
        _stoklar = stoklar;
        _satislar = satislar;
        _alislar = alislar;
        _satisDetaylar = <Map<String, dynamic>>[];
        _alisDetaylar = <Map<String, dynamic>>[];
        _yukleniyor = false;
      });

      final satisIds = satislar
          .where((e) => !_iptalMi(e['durum']))
          .map((e) => _int(e['satis_id']))
          .whereType<int>()
          .toSet()
          .toList();
      final alisIds = alislar
          .where((e) => !_iptalMi(e['durum']))
          .map((e) => _int(e['alis_id']))
          .whereType<int>()
          .toSet()
          .toList();

      // Bu tarih aralığında belge yoksa detay sorgusu hiç yapılmaz.
      final detaylar = await Future.wait([
        _detaylariIdlerleGetir(
          tablo: 'satis_detay',
          idKolonu: 'satis_id',
          ids: satisIds,
          kolonlar: 'satis_id, stok_id, miktar, birim_fiyat, alis_fiyati, indirim',
        ),
        _detaylariIdlerleGetir(
          tablo: 'alis_detay',
          idKolonu: 'alis_id',
          ids: alisIds,
          kolonlar: 'alis_id, stok_id, miktar, birim_fiyat, tutar',
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _satisDetaylar = List<Map<String, dynamic>>.from(detaylar[0]);
        _alisDetaylar = List<Map<String, dynamic>>.from(detaylar[1]);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _mesaj('Stok raporu yüklenemedi: $e', Colors.red);
    }
  }

  Future<void> _verileriYukle() async {
    if (!mounted) return;

    setState(() => _yukleniyor = true);

    try {
      final baslangicIso = DateTime(
        _baslangic.year,
        _baslangic.month,
        _baslangic.day,
      ).toUtc().toIso8601String();

      final bitisIso = DateTime(
        _bitis.year,
        _bitis.month,
        _bitis.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from('cariler')
            .select(
              'cari_id, unvan, cari_tipi, bakiye, risk_limiti, aktif',
            )
            .order('unvan'),
        SupabaseService.supabase
            .from('satis_baslik')
            .select(
              'satis_id, fatura_no, belge_no, tarih, cari_id, '
              'toplam_tutar, kdv_toplam, genel_toplam, '
              'odeme_tipi, durum, kullanici',
            )
            .gte('tarih', baslangicIso)
            .lte('tarih', bitisIso)
            .order('tarih', ascending: false),
        SupabaseService.supabase
            .from('alis_baslik')
            .select(
              'alis_id, fatura_no, tarih, cari_id, '
              'toplam_tutar, kdv_toplam, genel_toplam, '
              'odeme_tipi, durum, kullanici',
            )
            .gte('tarih', baslangicIso)
            .lte('tarih', bitisIso)
            .order('tarih', ascending: false),
        SupabaseService.supabase
            .from('stoklar')
            .select(
              'stok_id, urun_adi, uretici_kodu, oem_no, marka, model, '
              'stok_miktari, alis_fiyati, satis_fiyati_perakende, '
              'satis_fiyati_toptan, raf',
            )
            .order('urun_adi'),
        SupabaseService.supabase
            .from('cari_hareket')
            .select(
              'hareket_id, tarih, cari_id, islem_tipi, belge_no, '
              'borc, alacak, aciklama, kullanici',
            )
            .gte('tarih', baslangicIso)
            .lte('tarih', bitisIso)
            .order('tarih', ascending: false),
        SupabaseService.supabase
            .from('cari_hareket')
            .select(
              'hareket_id, tarih, cari_id, islem_tipi, belge_no, '
              'borc, alacak, aciklama, kullanici',
            )
            .order('tarih', ascending: true),
        SupabaseService.supabase
            .from('kasa_hareket')
            .select(
              'hareket_id, tarih, kasa_id, tip, tutar, belge_no, '
              'aciklama, cari_id, kullanici',
            )
            .gte('tarih', baslangicIso)
            .lte('tarih', bitisIso)
            .order('tarih', ascending: false),
        SupabaseService.supabase
            .from('kasa_hareket')
            .select(
              'hareket_id, tarih, kasa_id, tip, tutar, belge_no, '
              'aciklama, cari_id, kullanici',
            )
            .order('tarih', ascending: true),
        SupabaseService.supabase
            .from('satis_detay')
            .select(
              'satis_id, stok_id, miktar, birim_fiyat, '
              'alis_fiyati, indirim',
            ),
        SupabaseService.supabase
            .from('alis_detay')
            .select(
              'alis_id, stok_id, miktar, birim_fiyat, tutar',
            ),
        SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi, kasa_tipi')
            .order('kasa_adi'),
        SupabaseService.supabase
            .from('giderler')
            .select(
              'gider_id, gider_no, tarih, kategori, tutar, '
              'kasa_id, cari_id, belge_no, aciklama, kullanici, iptal',
            )
            .gte('tarih', baslangicIso)
            .lte('tarih', bitisIso)
            .order('tarih', ascending: false),
      ]);

      if (!mounted) return;

      setState(() {
        _cariler = List<Map<String, dynamic>>.from(sonuclar[0] as List);
        _satislar = List<Map<String, dynamic>>.from(sonuclar[1] as List);
        _alislar = List<Map<String, dynamic>>.from(sonuclar[2] as List);
        _stoklar = List<Map<String, dynamic>>.from(sonuclar[3] as List);
        _cariHareketler =
            List<Map<String, dynamic>>.from(sonuclar[4] as List);
        _tumCariHareketler =
            List<Map<String, dynamic>>.from(sonuclar[5] as List);
        _kasaHareketler =
            List<Map<String, dynamic>>.from(sonuclar[6] as List);
        _tumKasaHareketler =
            List<Map<String, dynamic>>.from(sonuclar[7] as List);
        _satisDetaylar =
            List<Map<String, dynamic>>.from(sonuclar[8] as List);
        _alisDetaylar =
            List<Map<String, dynamic>>.from(sonuclar[9] as List);
        _kasalar = List<Map<String, dynamic>>.from(sonuclar[10] as List);
        _giderler = List<Map<String, dynamic>>.from(sonuclar[11] as List);

        _tamVeriYuklendi = true;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _yukleniyor = false);

      _mesaj(
        'Rapor verileri yüklenemedi: $e',
        Colors.red,
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

  String _kisaTarih(DateTime tarih) {
    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year}';
  }

  bool _iptalMi(dynamic durum) {
    final metin = _metin(durum).toUpperCase();
    return metin == 'IPTAL' || metin == 'İPTAL';
  }

  int? _int(dynamic deger) {
    return int.tryParse(deger?.toString() ?? '');
  }

  String _cariAdi(dynamic cariId) {
    final id = _int(cariId);
    if (id == null) return '-';

    for (final cari in _cariler) {
      if (_int(cari['cari_id']) == id) {
        return _metin(cari['unvan']);
      }
    }

    return '-';
  }

  String _kasaAdi(dynamic kasaId) {
    final id = _int(kasaId);
    if (id == null) return '-';

    for (final kasa in _kasalar) {
      if (_int(kasa['kasa_id']) == id) {
        return _metin(kasa['kasa_adi']);
      }
    }

    return '-';
  }

  String _stokAdi(dynamic stokId) {
    final id = _int(stokId);
    if (id == null) return '-';

    for (final stok in _stoklar) {
      if (_int(stok['stok_id']) == id) {
        return _metin(stok['urun_adi']);
      }
    }

    return '-';
  }

  Future<void> _tarihSec({required bool baslangic}) async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: baslangic ? _baslangic : _bitis,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (secilen == null) return;

    setState(() {
      if (baslangic) {
        _baslangic = secilen;
        if (_baslangic.isAfter(_bitis)) {
          _bitis = secilen;
        }
      } else {
        _bitis = secilen;
        if (_bitis.isBefore(_baslangic)) {
          _baslangic = secilen;
        }
      }
    });

    await _verileriYukle();
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: renk,
      ),
    );
  }

  List<String> get _kullanicilar {
    final liste = <String>{};

    for (final item in [..._satislar, ..._alislar]) {
      final kullanici = item['kullanici']?.toString().trim() ?? '';
      if (kullanici.isNotEmpty) {
        liste.add(kullanici);
      }
    }

    final sonuc = liste.toList()..sort();
    return sonuc;
  }

  List<Map<String, dynamic>> get _filtreliSatislar {
    final kelimeler = _aramaController.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    return _satislar.where((satis) {
      if (_secilenCariId != null &&
          _int(satis['cari_id']) != _secilenCariId) {
        return false;
      }

      if (_secilenKullanici != null &&
          _metin(satis['kullanici']) != _secilenKullanici) {
        return false;
      }

      final durum = _metin(satis['durum']).toUpperCase();

      if (_durumFiltresi != 'TÜMÜ' && durum != _durumFiltresi) {
        return false;
      }

      if (kelimeler.isEmpty) return true;

      final metin = [
        satis['fatura_no'],
        satis['belge_no'],
        _cariAdi(satis['cari_id']),
        satis['odeme_tipi'],
        satis['durum'],
        satis['kullanici'],
      ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();

      return kelimeler.every(metin.contains);
    }).toList();
  }

  List<Map<String, dynamic>> get _filtreliAlislar {
    final kelimeler = _aramaController.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    return _alislar.where((alis) {
      if (_secilenCariId != null &&
          _int(alis['cari_id']) != _secilenCariId) {
        return false;
      }

      if (_secilenKullanici != null &&
          _metin(alis['kullanici']) != _secilenKullanici) {
        return false;
      }

      final durum = _metin(alis['durum']).toUpperCase();

      if (_durumFiltresi != 'TÜMÜ' && durum != _durumFiltresi) {
        return false;
      }

      if (kelimeler.isEmpty) return true;

      final metin = [
        alis['fatura_no'],
        _cariAdi(alis['cari_id']),
        alis['odeme_tipi'],
        alis['durum'],
        alis['kullanici'],
      ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();

      return kelimeler.every(metin.contains);
    }).toList();
  }

  double _satisKar(dynamic satisId) {
    final id = _int(satisId);
    if (id == null) return 0;

    double kar = 0;

    for (final detay in _satisDetaylar) {
      if (_int(detay['satis_id']) != id) continue;

      final miktar = _sayi(detay['miktar']);
      final satisFiyati = _sayi(detay['birim_fiyat']);
      final alisFiyati = _sayi(detay['alis_fiyati']);
      final indirim = _sayi(detay['indirim']);

      final netFiyat = satisFiyati * (1 - indirim / 100);
      kar += (netFiyat - alisFiyati) * miktar;
    }

    return kar;
  }

  Widget _ortakFiltreler({
    required String aramaIpuclari,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _aramaController,
              decoration: InputDecoration(
                hintText: aramaIpuclari,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _aramaController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _aramaController.clear,
                        icon: const Icon(Icons.clear),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _tarihSec(baslangic: true),
            icon: const Icon(Icons.calendar_today),
            label: Text('Başlangıç: ${_kisaTarih(_baslangic)}'),
          ),
          OutlinedButton.icon(
            onPressed: () => _tarihSec(baslangic: false),
            icon: const Icon(Icons.event),
            label: Text('Bitiş: ${_kisaTarih(_bitis)}'),
          ),
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<int?>(
              value: _secilenCariId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Cari',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Tüm Cariler'),
                ),
                ..._cariler.map(
                  (cari) => DropdownMenuItem<int?>(
                    value: _int(cari['cari_id']),
                    child: Text(
                      _metin(cari['unvan']),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (deger) {
                setState(() => _secilenCariId = deger);
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              value: _secilenKullanici,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tüm Kullanıcılar'),
                ),
                ..._kullanicilar.map(
                  (kullanici) => DropdownMenuItem<String?>(
                    value: kullanici,
                    child: Text(kullanici),
                  ),
                ),
              ],
              onChanged: (deger) {
                setState(() => _secilenKullanici = deger);
              },
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _durumFiltresi,
              decoration: const InputDecoration(
                labelText: 'Durum',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'TÜMÜ',
                  child: Text('Tüm Durumlar'),
                ),
                DropdownMenuItem(
                  value: 'ONAYLANDI',
                  child: Text('Onaylandı'),
                ),
                DropdownMenuItem(
                  value: 'IPTAL',
                  child: Text('İptal'),
                ),
              ],
              onChanged: (deger) {
                if (deger == null) return;
                setState(() => _durumFiltresi = deger);
              },
            ),
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _verileriYukle,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _ozetKarti({
    required String baslik,
    required String deger,
    required IconData ikon,
    required Color renk,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: MobilYatayRow(
            children: [
              CircleAvatar(
                backgroundColor: renk.withOpacity(0.14),
                child: Icon(ikon, color: renk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deger,
                      style: TextStyle(
                        color: renk,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _satisRaporu() {
    final satislar = _filtreliSatislar;

    double araToplam = 0;
    double kdv = 0;
    double genel = 0;
    double kar = 0;
    double toplamMaliyet = 0;
    double toplamSatilanAdet = 0;

    int onayliFatura = 0;
    int iptalFatura = 0;

    final odemeDagilimi =
        <String, double>{};

    final cariCiro =
        <int, double>{};

    final stokSatis =
        <int, Map<String, double>>{};

    final gecerliSatisIdleri = satislar
        .where((satis) => !_iptalMi(satis['durum']))
        .map((satis) => _int(satis['satis_id']))
        .whereType<int>()
        .toSet();

    for (final satis in satislar) {
      final iptalMi =
          _iptalMi(satis['durum']);

      if (iptalMi) {
        iptalFatura++;
        continue;
      }

      onayliFatura++;

      final satisGenel =
          _sayi(satis['genel_toplam']);

      araToplam +=
          _sayi(satis['toplam_tutar']);

      kdv +=
          _sayi(satis['kdv_toplam']);

      genel += satisGenel;

      final satisKar =
          _satisKar(satis['satis_id']);

      kar += satisKar;
      toplamMaliyet +=
          satisGenel - satisKar;

      final odemeTipi =
          _metin(satis['odeme_tipi']);

      odemeDagilimi[odemeTipi] =
          (odemeDagilimi[odemeTipi] ?? 0) +
              satisGenel;

      final cariId =
          _int(satis['cari_id']);

      if (cariId != null) {
        cariCiro[cariId] =
            (cariCiro[cariId] ?? 0) +
                satisGenel;
      }
    }

    for (final detay in _satisDetaylar) {
      final satisId =
          _int(detay['satis_id']);

      if (satisId == null ||
          !gecerliSatisIdleri
              .contains(satisId)) {
        continue;
      }

      final stokId =
          _int(detay['stok_id']);

      if (stokId == null) continue;

      final miktar =
          _sayi(detay['miktar']);

      final birimFiyat =
          _sayi(detay['birim_fiyat']);

      final indirim =
          _sayi(detay['indirim']);

      final netBirim =
          birimFiyat *
              (1 - indirim / 100);

      var maliyetBirim =
          _sayi(detay['alis_fiyati']);

      if (maliyetBirim <= 0) {
        for (final stok in _stoklar) {
          if (_int(stok['stok_id']) ==
              stokId) {
            maliyetBirim =
                _sayi(
              stok['alis_fiyati'],
            );
            break;
          }
        }
      }

      final ciro =
          miktar * netBirim;

      final maliyet =
          miktar * maliyetBirim;

      final satirKar =
          ciro - maliyet;

      toplamSatilanAdet += miktar;

      final ozet =
          stokSatis.putIfAbsent(
        stokId,
        () => {
          'miktar': 0,
          'ciro': 0,
          'maliyet': 0,
          'kar': 0,
        },
      );

      ozet['miktar'] =
          (ozet['miktar'] ?? 0) +
              miktar;

      ozet['ciro'] =
          (ozet['ciro'] ?? 0) +
              ciro;

      ozet['maliyet'] =
          (ozet['maliyet'] ?? 0) +
              maliyet;

      ozet['kar'] =
          (ozet['kar'] ?? 0) +
              satirKar;
    }

    final ortalamaFatura =
        onayliFatura == 0
            ? 0.0
            : genel / onayliFatura;

    final karMarji =
        genel <= 0
            ? 0.0
            : kar / genel * 100;

    final enIyiCariler =
        cariCiro.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(a.value),
          );

    final enCokSatilan =
        stokSatis.entries.toList()
          ..sort(
            (a, b) =>
                (b.value['miktar'] ?? 0)
                    .compareTo(
              a.value['miktar'] ?? 0,
            ),
          );

    final odemeler =
        odemeDagilimi.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(a.value),
          );

    return Column(
      children: [
        _ortakFiltreler(
          aramaIpuclari:
              'Fatura no, belge no, cari, ödeme tipi...',
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            0,
          ),
          child: MobilYatayRow(
            children: [
              _ozetKarti(
                baslik:
                    'Net Satış Cirosu',
                deger: _para(genel),
                ikon: Icons.payments,
                renk: Colors.green,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Satılan Adet',
                deger:
                    toplamSatilanAdet
                        .toStringAsFixed(0),
                ikon: Icons.inventory_2,
                renk: Colors.blue,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Satılan Mal Maliyeti',
                deger:
                    _para(toplamMaliyet),
                ikon:
                    Icons.price_check,
                renk: Colors.orange,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Gerçekleşen Kâr',
                deger:
                    '${_para(kar)}  (%${karMarji.toStringAsFixed(1)})',
                ikon:
                    Icons.trending_up,
                renk: kar >= 0
                    ? Colors.teal
                    : Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Ort. Fatura',
                deger:
                    _para(ortalamaFatura),
                ikon:
                    Icons.receipt_long,
                renk:
                    Colors.deepPurple,
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            4,
            12,
            0,
          ),
          child: MobilYatayRow(
            children: [
              _ozetKarti(
                baslik:
                    'Onaylı Fatura',
                deger:
                    '$onayliFatura',
                ikon:
                    Icons.check_circle,
                renk: Colors.green,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'İptal Fatura',
                deger:
                    '$iptalFatura',
                ikon: Icons.cancel,
                renk: Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Ara Toplam',
                deger:
                    _para(araToplam),
                ikon:
                    Icons.calculate,
                renk: Colors.blueGrey,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'KDV Toplamı',
                deger:
                    _para(kdv),
                ikon: Icons.percent,
                renk: Colors.orange,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Fatura Adedi',
                deger:
                    '${satislar.length}',
                ikon:
                    Icons.description,
                renk: Colors.indigo,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 128,
          child: MobilYatayRow(
            children: [
              Expanded(
                child: Card(
                  margin:
                      const EdgeInsets.only(
                    left: 12,
                    right: 4,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'En Çok Satış Yapılan Cariler',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Expanded(
                          child: enIyiCariler
                                  .isEmpty
                              ? const Center(
                                  child: Text(
                                    'Veri yok',
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      enIyiCariler
                                          .take(5)
                                          .length,
                                  itemBuilder:
                                      (_, index) {
                                    final item =
                                        enIyiCariler[
                                            index];

                                    return MobilYatayRow(
                                      children: [
                                        Expanded(
                                          child:
                                              Text(
                                            '${index + 1}. ${_cariAdi(item.key)}',
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                        ),
                                        Text(
                                          _para(
                                            item.value,
                                          ),
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'En Çok Satılan Ürünler',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Expanded(
                          child: enCokSatilan
                                  .isEmpty
                              ? const Center(
                                  child: Text(
                                    'Veri yok',
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      enCokSatilan
                                          .take(5)
                                          .length,
                                  itemBuilder:
                                      (_, index) {
                                    final item =
                                        enCokSatilan[
                                            index];

                                    return MobilYatayRow(
                                      children: [
                                        Expanded(
                                          child:
                                              Text(
                                            '${index + 1}. ${_stokAdi(item.key)}',
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${(item.value['miktar'] ?? 0).toStringAsFixed(0)} Adet',
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  margin:
                      const EdgeInsets.only(
                    left: 4,
                    right: 12,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Ödeme Dağılımı',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Expanded(
                          child: odemeler.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Veri yok',
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      odemeler
                                          .take(5)
                                          .length,
                                  itemBuilder:
                                      (_, index) {
                                    final item =
                                        odemeler[
                                            index];

                                    return MobilYatayRow(
                                      children: [
                                        Expanded(
                                          child:
                                              Text(
                                            item.key,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                        ),
                                        Text(
                                          _para(
                                            item.value,
                                          ),
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: satislar.isEmpty
              ? const Center(
                  child: Text(
                    'Satış kaydı bulunamadı.',
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  itemCount:
                      satislar.length,
                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    height: 8,
                  ),
                  itemBuilder:
                      (context, index) {
                    final satis =
                        satislar[index];

                    final iptalMi =
                        _iptalMi(
                      satis['durum'],
                    );

                    final satisKar =
                        _satisKar(
                      satis['satis_id'],
                    );

                    final satisGenel =
                        _sayi(
                      satis[
                          'genel_toplam'],
                    );

                    final satisKarMarji =
                        satisGenel <= 0
                            ? 0.0
                            : satisKar /
                                satisGenel *
                                100;

                    return Card(
                      color: iptalMi
                          ? Colors.red
                              .withOpacity(
                              0.035,
                            )
                          : null,
                      child: ListTile(
                        leading:
                            CircleAvatar(
                          backgroundColor:
                              (iptalMi
                                      ? Colors.red
                                      : Colors
                                          .green)
                                  .withOpacity(
                            0.14,
                          ),
                          child: Icon(
                            Icons
                                .receipt_long,
                            color: iptalMi
                                ? Colors.red
                                : Colors
                                    .green,
                          ),
                        ),
                        title: Text(
                          _cariAdi(
                            satis[
                                'cari_id'],
                          ),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        subtitle: Text(
                          'Fatura: ${_metin(satis['fatura_no'])}\n'
                          'Belge: ${_metin(satis['belge_no'])} • '
                          '${_tarih(satis['tarih'])}\n'
                          'Ödeme: ${_metin(satis['odeme_tipi'])} • '
                          'Kullanıcı: ${_metin(satis['kullanici'])}',
                        ),
                        trailing:
                            SizedBox(
                          width: 245,
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .end,
                            children: [
                              Text(
                                _para(
                                  satis[
                                      'genel_toplam'],
                                ),
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                'Kâr: ${_para(satisKar)} • %${satisKarMarji.toStringAsFixed(1)}',
                                style:
                                    TextStyle(
                                  color: satisKar >=
                                          0
                                      ? Colors
                                          .teal
                                      : Colors
                                          .red,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                              Text(
                                _metin(
                                  satis[
                                      'durum'],
                                ),
                                style:
                                    TextStyle(
                                  color: iptalMi
                                      ? Colors.red
                                      : Colors
                                          .green,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _alisRaporu() {
    final alislar = _filtreliAlislar;

    double araToplam = 0;
    double kdv = 0;
    double genel = 0;
    double toplamAlinanAdet = 0;
    double ortalamaBirimMaliyet = 0;
    double toplamBirimMaliyetTutari = 0;

    int onayliFatura = 0;
    int iptalFatura = 0;

    final odemeDagilimi =
        <String, double>{};

    final cariAlis =
        <int, double>{};

    final stokAlis =
        <int, Map<String, double>>{};

    final gecerliAlisIdleri = alislar
        .where((alis) => !_iptalMi(alis['durum']))
        .map((alis) => _int(alis['alis_id']))
        .whereType<int>()
        .toSet();

    for (final alis in alislar) {
      final iptalMi =
          _iptalMi(alis['durum']);

      if (iptalMi) {
        iptalFatura++;
        continue;
      }

      onayliFatura++;

      final alisGenel =
          _sayi(alis['genel_toplam']);

      araToplam +=
          _sayi(alis['toplam_tutar']);

      kdv +=
          _sayi(alis['kdv_toplam']);

      genel += alisGenel;

      final odemeTipi =
          _metin(alis['odeme_tipi']);

      odemeDagilimi[odemeTipi] =
          (odemeDagilimi[odemeTipi] ?? 0) +
              alisGenel;

      final cariId =
          _int(alis['cari_id']);

      if (cariId != null) {
        cariAlis[cariId] =
            (cariAlis[cariId] ?? 0) +
                alisGenel;
      }
    }

    for (final detay in _alisDetaylar) {
      final alisId =
          _int(detay['alis_id']);

      if (alisId == null ||
          !gecerliAlisIdleri
              .contains(alisId)) {
        continue;
      }

      final stokId =
          _int(detay['stok_id']);

      if (stokId == null) continue;

      final miktar =
          _sayi(detay['miktar']);

      final birimFiyat =
          _sayi(detay['birim_fiyat']);

      final tutar =
          _sayi(detay['tutar']) > 0
              ? _sayi(detay['tutar'])
              : miktar * birimFiyat;

      toplamAlinanAdet += miktar;
      toplamBirimMaliyetTutari += tutar;

      final ozet =
          stokAlis.putIfAbsent(
        stokId,
        () => {
          'miktar': 0,
          'tutar': 0,
          'birim_toplam': 0,
        },
      );

      ozet['miktar'] =
          (ozet['miktar'] ?? 0) +
              miktar;

      ozet['tutar'] =
          (ozet['tutar'] ?? 0) +
              tutar;

      ozet['birim_toplam'] =
          (ozet['birim_toplam'] ?? 0) +
              (miktar * birimFiyat);
    }

    ortalamaBirimMaliyet =
        toplamAlinanAdet <= 0
            ? 0
            : toplamBirimMaliyetTutari /
                toplamAlinanAdet;

    final ortalamaFatura =
        onayliFatura == 0
            ? 0.0
            : genel / onayliFatura;

    final enCokAlimYapilanCariler =
        cariAlis.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(a.value),
          );

    final enCokAlinanUrunler =
        stokAlis.entries.toList()
          ..sort(
            (a, b) =>
                (b.value['miktar'] ?? 0)
                    .compareTo(
              a.value['miktar'] ?? 0,
            ),
          );

    final odemeler =
        odemeDagilimi.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(a.value),
          );

    return Column(
      children: [
        _ortakFiltreler(
          aramaIpuclari:
              'Fatura no, tedarikçi, ödeme tipi...',
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            0,
          ),
          child: MobilYatayRow(
            children: [
              _ozetKarti(
                baslik:
                    'Toplam Alış',
                deger: _para(genel),
                ikon:
                    Icons.shopping_cart_checkout,
                renk: Colors.blue,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Alınan Adet',
                deger:
                    toplamAlinanAdet
                        .toStringAsFixed(0),
                ikon: Icons.inventory_2,
                renk: Colors.deepPurple,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Ort. Birim Maliyet',
                deger:
                    _para(ortalamaBirimMaliyet),
                ikon:
                    Icons.price_change,
                renk: Colors.orange,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Ort. Fatura',
                deger:
                    _para(ortalamaFatura),
                ikon:
                    Icons.receipt_long,
                renk: Colors.teal,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'KDV Toplamı',
                deger: _para(kdv),
                ikon: Icons.percent,
                renk: Colors.redAccent,
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            4,
            12,
            0,
          ),
          child: MobilYatayRow(
            children: [
              _ozetKarti(
                baslik:
                    'Onaylı Fatura',
                deger:
                    '$onayliFatura',
                ikon:
                    Icons.check_circle,
                renk: Colors.green,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'İptal Fatura',
                deger:
                    '$iptalFatura',
                ikon: Icons.cancel,
                renk: Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Ara Toplam',
                deger:
                    _para(araToplam),
                ikon:
                    Icons.calculate,
                renk: Colors.blueGrey,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Fatura Adedi',
                deger:
                    '${alislar.length}',
                ikon:
                    Icons.description,
                renk: Colors.indigo,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Alış Toplamı',
                deger:
                    _para(genel),
                ikon:
                    Icons.account_balance_wallet,
                renk: Colors.brown,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 128,
          child: MobilYatayRow(
            children: [
              Expanded(
                child: Card(
                  margin:
                      const EdgeInsets.only(
                    left: 12,
                    right: 4,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'En Çok Alım Yapılan Tedarikçiler',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Expanded(
                          child:
                              enCokAlimYapilanCariler
                                      .isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Veri yok',
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount:
                                          enCokAlimYapilanCariler
                                              .take(5)
                                              .length,
                                      itemBuilder:
                                          (_, index) {
                                        final item =
                                            enCokAlimYapilanCariler[
                                                index];

                                        return MobilYatayRow(
                                          children: [
                                            Expanded(
                                              child:
                                                  Text(
                                                '${index + 1}. ${_cariAdi(item.key)}',
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                              ),
                                            ),
                                            Text(
                                              _para(
                                                item.value,
                                              ),
                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'En Çok Alınan Ürünler',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Expanded(
                          child:
                              enCokAlinanUrunler
                                      .isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Veri yok',
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount:
                                          enCokAlinanUrunler
                                              .take(5)
                                              .length,
                                      itemBuilder:
                                          (_, index) {
                                        final item =
                                            enCokAlinanUrunler[
                                                index];

                                        return MobilYatayRow(
                                          children: [
                                            Expanded(
                                              child:
                                                  Text(
                                                '${index + 1}. ${_stokAdi(item.key)}',
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${(item.value['miktar'] ?? 0).toStringAsFixed(0)} Adet',
                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  margin:
                      const EdgeInsets.only(
                    left: 4,
                    right: 12,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Ödeme Dağılımı',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Expanded(
                          child: odemeler.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Veri yok',
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      odemeler
                                          .take(5)
                                          .length,
                                  itemBuilder:
                                      (_, index) {
                                    final item =
                                        odemeler[
                                            index];

                                    return MobilYatayRow(
                                      children: [
                                        Expanded(
                                          child:
                                              Text(
                                            item.key,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                        ),
                                        Text(
                                          _para(
                                            item.value,
                                          ),
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: alislar.isEmpty
              ? const Center(
                  child: Text(
                    'Alış kaydı bulunamadı.',
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  itemCount:
                      alislar.length,
                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    height: 8,
                  ),
                  itemBuilder:
                      (context, index) {
                    final alis =
                        alislar[index];

                    final iptalMi =
                        _iptalMi(
                      alis['durum'],
                    );

                    return Card(
                      color: iptalMi
                          ? Colors.red
                              .withOpacity(
                              0.035,
                            )
                          : null,
                      child: ListTile(
                        leading:
                            CircleAvatar(
                          backgroundColor:
                              (iptalMi
                                      ? Colors.red
                                      : Colors
                                          .blue)
                                  .withOpacity(
                            0.14,
                          ),
                          child: Icon(
                            Icons
                                .shopping_cart,
                            color: iptalMi
                                ? Colors.red
                                : Colors.blue,
                          ),
                        ),
                        title: Text(
                          _cariAdi(
                            alis['cari_id'],
                          ),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        subtitle: Text(
                          'Fatura: ${_metin(alis['fatura_no'])}\n'
                          '${_tarih(alis['tarih'])}\n'
                          'Ödeme: ${_metin(alis['odeme_tipi'])} • '
                          'Kullanıcı: ${_metin(alis['kullanici'])}',
                        ),
                        trailing:
                            SizedBox(
                          width: 210,
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .end,
                            children: [
                              Text(
                                _para(
                                  alis[
                                      'genel_toplam'],
                                ),
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                _metin(
                                  alis[
                                      'durum'],
                                ),
                                style:
                                    TextStyle(
                                  color: iptalMi
                                      ? Colors.red
                                      : Colors
                                          .green,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _stokRaporu() {
    final arama =
        _aramaController.text.toLowerCase().trim();

    final gecerliSatisIdleri = _satislar
        .where((satis) => !_iptalMi(satis['durum']))
        .map((satis) => _int(satis['satis_id']))
        .whereType<int>()
        .toSet();

    final gecerliAlisIdleri = _alislar
        .where((alis) => !_iptalMi(alis['durum']))
        .map((alis) => _int(alis['alis_id']))
        .whereType<int>()
        .toSet();

    final satisOzetleri =
        <int, Map<String, double>>{};

    for (final detay in _satisDetaylar) {
      final satisId =
          _int(detay['satis_id']);

      final stokId =
          _int(detay['stok_id']);

      if (satisId == null ||
          stokId == null ||
          !gecerliSatisIdleri.contains(satisId)) {
        continue;
      }

      final miktar =
          _sayi(detay['miktar']);

      final birimFiyat =
          _sayi(detay['birim_fiyat']);

      final indirim =
          _sayi(detay['indirim']);

      final netBirimFiyat =
          birimFiyat *
              (1 - indirim / 100);

      final satisTutari =
          miktar * netBirimFiyat;

      var maliyetBirim =
          _sayi(detay['alis_fiyati']);

      if (maliyetBirim <= 0) {
        final stok = _stoklar
            .where(
              (s) =>
                  _int(s['stok_id']) ==
                  stokId,
            )
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (s) => s != null,
              orElse: () => null,
            );

        maliyetBirim =
            _sayi(stok?['alis_fiyati']);
      }

      final satisMaliyeti =
          miktar * maliyetBirim;

      final ozet =
          satisOzetleri.putIfAbsent(
        stokId,
        () => {
          'miktar': 0,
          'ciro': 0,
          'maliyet': 0,
          'kar': 0,
        },
      );

      ozet['miktar'] =
          (ozet['miktar'] ?? 0) + miktar;

      ozet['ciro'] =
          (ozet['ciro'] ?? 0) + satisTutari;

      ozet['maliyet'] =
          (ozet['maliyet'] ?? 0) +
              satisMaliyeti;

      ozet['kar'] =
          (ozet['kar'] ?? 0) +
              (satisTutari - satisMaliyeti);
    }

    final alisOzetleri =
        <int, Map<String, double>>{};

    for (final detay in _alisDetaylar) {
      final alisId =
          _int(detay['alis_id']);

      final stokId =
          _int(detay['stok_id']);

      if (alisId == null ||
          stokId == null ||
          !gecerliAlisIdleri.contains(alisId)) {
        continue;
      }

      final miktar =
          _sayi(detay['miktar']);

      final birimFiyat =
          _sayi(detay['birim_fiyat']);

      final ozet =
          alisOzetleri.putIfAbsent(
        stokId,
        () => {
          'miktar': 0,
          'tutar': 0,
        },
      );

      ozet['miktar'] =
          (ozet['miktar'] ?? 0) + miktar;

      ozet['tutar'] =
          (ozet['tutar'] ?? 0) +
              (miktar * birimFiyat);
    }

    final stoklar = _stoklar.where((stok) {
      if (arama.isEmpty) {
        return true;
      }

      final metin = [
        stok['urun_adi'],
        stok['uretici_kodu'],
        stok['oem_no'],
        stok['marka'],
        stok['model'],
        stok['raf'],
      ]
          .map((e) => e?.toString() ?? '')
          .join(' ')
          .toLowerCase();

      return arama
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .every(metin.contains);
    }).toList();

    stoklar.sort((a, b) {
      final aKar =
          satisOzetleri[_int(a['stok_id'])]?['kar'] ??
              0;

      final bKar =
          satisOzetleri[_int(b['stok_id'])]?['kar'] ??
              0;

      return bKar.compareTo(aKar);
    });

    double toplamAdet = 0;
    double stokMaliyeti = 0;
    double stokSatisDegeri = 0;
    double donemSatisAdedi = 0;
    double donemSatisCirosu = 0;
    double donemSatisMaliyeti = 0;
    double donemKar = 0;
    double donemAlisAdedi = 0;
    double donemAlisTutari = 0;

    int kritik = 0;
    int biten = 0;

    for (final stok in stoklar) {
      final stokId =
          _int(stok['stok_id']);

      final miktar =
          _sayi(stok['stok_miktari']);

      final alis =
          _sayi(stok['alis_fiyati']);

      final perakende =
          _sayi(
        stok['satis_fiyati_perakende'],
      );

      toplamAdet += miktar;
      stokMaliyeti += miktar * alis;
      stokSatisDegeri +=
          miktar * perakende;

      if (miktar <= 2) {
        kritik++;
      }

      if (miktar <= 0) {
        biten++;
      }

      if (stokId != null) {
        final satis =
            satisOzetleri[stokId];

        final alisOzet =
            alisOzetleri[stokId];

        donemSatisAdedi +=
            satis?['miktar'] ?? 0;

        donemSatisCirosu +=
            satis?['ciro'] ?? 0;

        donemSatisMaliyeti +=
            satis?['maliyet'] ?? 0;

        donemKar +=
            satis?['kar'] ?? 0;

        donemAlisAdedi +=
            alisOzet?['miktar'] ?? 0;

        donemAlisTutari +=
            alisOzet?['tutar'] ?? 0;
      }
    }

    final potansiyelKar =
        stokSatisDegeri - stokMaliyeti;

    final karMarji =
        donemSatisCirosu <= 0
            ? 0.0
            : (donemKar /
                    donemSatisCirosu) *
                100;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment:
                WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 380,
                child: TextField(
                  controller:
                      _aramaController,
                  decoration:
                      InputDecoration(
                    hintText:
                        'Ürün, üretici kodu, OEM, marka, model, RAF...',
                    prefixIcon:
                        const Icon(
                      Icons.search,
                    ),
                    suffixIcon:
                        _aramaController
                                .text.isEmpty
                            ? null
                            : IconButton(
                                onPressed:
                                    _aramaController
                                        .clear,
                                icon:
                                    const Icon(
                                  Icons.clear,
                                ),
                              ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(12),
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _tarihSec(
                  baslangic: true,
                ),
                icon: const Icon(
                  Icons.calendar_today,
                ),
                label: Text(
                  'Başlangıç: ${_kisaTarih(_baslangic)}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _tarihSec(
                  baslangic: false,
                ),
                icon: const Icon(
                  Icons.event,
                ),
                label: Text(
                  'Bitiş: ${_kisaTarih(_bitis)}',
                ),
              ),
              Tooltip(
                message:
                    'Satılan adet, ciro ve gerçekleşen kâr seçilen tarih aralığına göre hesaplanır.',
                child: Chip(
                  avatar: const Icon(
                    Icons.info_outline,
                    size: 18,
                  ),
                  label: Text(
                    '${_kisaTarih(_baslangic)} - ${_kisaTarih(_bitis)}',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Yenile',
                onPressed:
                    _verileriYukle,
                icon: const Icon(
                  Icons.refresh,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            0,
          ),
          child: MobilYatayRow(
            children: [
              _ozetKarti(
                baslik:
                    'Stok Çeşidi / Adet',
                deger:
                    '${stoklar.length} / ${toplamAdet.toStringAsFixed(0)}',
                ikon: Icons.inventory_2,
                renk: Colors.blue,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Mevcut Stok Maliyeti',
                deger:
                    _para(stokMaliyeti),
                ikon:
                    Icons.account_balance_wallet,
                renk: Colors.orange,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Satış Potansiyeli',
                deger:
                    _para(stokSatisDegeri),
                ikon:
                    Icons.trending_up,
                renk: Colors.green,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Potansiyel Kâr',
                deger:
                    _para(potansiyelKar),
                ikon:
                    Icons.auto_graph,
                renk:
                    potansiyelKar >= 0
                        ? Colors.teal
                        : Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Kritik / Biten',
                deger:
                    '$kritik / $biten',
                ikon:
                    Icons.warning_amber,
                renk: Colors.red,
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            4,
            12,
            0,
          ),
          child: MobilYatayRow(
            children: [
              _ozetKarti(
                baslik:
                    'Dönem Satılan Adet',
                deger:
                    donemSatisAdedi
                        .toStringAsFixed(0),
                ikon:
                    Icons.shopping_cart_checkout,
                renk: Colors.blue,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Dönem Satış Cirosu',
                deger:
                    _para(donemSatisCirosu),
                ikon:
                    Icons.payments,
                renk: Colors.green,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Satılan Mal Maliyeti',
                deger:
                    _para(
                  donemSatisMaliyeti,
                ),
                ikon:
                    Icons.price_check,
                renk: Colors.orange,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Gerçekleşen Kâr',
                deger:
                    '${_para(donemKar)}  (%${karMarji.toStringAsFixed(1)})',
                ikon:
                    Icons.ssid_chart,
                renk: donemKar >= 0
                    ? Colors.teal
                    : Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Dönem Alış',
                deger:
                    '${donemAlisAdedi.toStringAsFixed(0)} Adet • ${_para(donemAlisTutari)}',
                ikon:
                    Icons.shopping_bag,
                renk:
                    Colors.deepPurple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: stoklar.isEmpty
              ? const Center(
                  child: Text(
                    'Stok bulunamadı.',
                  ),
                )
              : Card(
                  margin:
                      const EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    12,
                  ),
                  child:
                      SingleChildScrollView(
                    scrollDirection:
                        Axis.horizontal,
                    child: SingleChildScrollView(
                      child: MobilTablo(
                                  child: DataTable(
                        headingRowColor:
                            MaterialStatePropertyAll(
                          Colors
                              .blueGrey
                              .shade50,
                        ),
                        columns: const [
                          DataColumn(
                            label:
                                Text('Ürün'),
                          ),
                          DataColumn(
                            label:
                                Text('Kod'),
                          ),
                          DataColumn(
                            label:
                                Text('Marka'),
                          ),
                          DataColumn(
                            label:
                                Text('Model'),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Mevcut',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Alış F.',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Perakende',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Toptan',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Dönem Alış',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Satılan',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Satış Cirosu',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Satış Maliyeti',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Kâr',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Kâr %',
                            ),
                          ),
                        ],
                        rows: stoklar.map(
                          (stok) {
                            final stokId =
                                _int(
                              stok['stok_id'],
                            );

                            final miktar =
                                _sayi(
                              stok[
                                  'stok_miktari'],
                            );

                            final satis =
                                stokId == null
                                    ? null
                                    : satisOzetleri[
                                        stokId];

                            final alisOzet =
                                stokId == null
                                    ? null
                                    : alisOzetleri[
                                        stokId];

                            final ciro =
                                satis?['ciro'] ??
                                    0;

                            final kar =
                                satis?['kar'] ??
                                    0;

                            final urunKarMarji =
                                ciro <= 0
                                    ? 0.0
                                    : (kar /
                                            ciro) *
                                        100;

                            final kritikMi =
                                miktar <= 2;

                            return DataRow(
                              color:
                                  MaterialStateProperty
                                      .resolveWith(
                                (states) {
                                  if (kritikMi) {
                                    return Colors
                                        .red
                                        .withOpacity(
                                      0.045,
                                    );
                                  }

                                  if (kar > 0) {
                                    return Colors
                                        .green
                                        .withOpacity(
                                      0.025,
                                    );
                                  }

                                  return null;
                                },
                              ),
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 290,
                                    child: Text(
                                      _metin(
                                        stok[
                                            'urun_adi'],
                                      ),
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SelectableText(
                                    _metin(
                                      stok[
                                          'uretici_kodu'],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _metin(
                                      stok[
                                          'marka'],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _metin(
                                      stok[
                                          'model'],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    miktar
                                        .toStringAsFixed(
                                      0,
                                    ),
                                    style:
                                        TextStyle(
                                      color:
                                          kritikMi
                                              ? Colors
                                                  .red
                                              : Colors
                                                  .green,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      stok[
                                          'alis_fiyati'],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      stok[
                                          'satis_fiyati_perakende'],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      stok[
                                          'satis_fiyati_toptan'],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (alisOzet?[
                                                'miktar'] ??
                                            0)
                                        .toStringAsFixed(
                                      0,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (satis?[
                                                'miktar'] ??
                                            0)
                                        .toStringAsFixed(
                                      0,
                                    ),
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      ciro,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      satis?[
                                              'maliyet'] ??
                                          0,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      kar,
                                    ),
                                    style:
                                        TextStyle(
                                      color:
                                          kar >= 0
                                              ? Colors
                                                  .teal
                                              : Colors
                                                  .red,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '%${urunKarMarji.toStringAsFixed(1)}',
                                    style:
                                        TextStyle(
                                      color:
                                          urunKarMarji >=
                                                  0
                                              ? Colors
                                                  .teal
                                              : Colors
                                                  .red,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ).toList(),
                      ),
                                ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _miniBilgi(String baslik, String deger) {
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
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _cariRaporu() {
    final arama =
        _aramaController.text.toLowerCase().trim();

    final cariler = _cariler.where((cari) {
      if (arama.isEmpty) return true;

      final metin = [
        cari['unvan'],
        cari['cari_tipi'],
      ]
          .map((e) => e?.toString() ?? '')
          .join(' ')
          .toLowerCase();

      return arama
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .every(metin.contains);
    }).toList();

    final bugun = DateTime.now();

    Map<String, double> yaslandirma(
      int cariId,
    ) {
      final hareketler =
          _tumCariHareketler
              .where(
                (h) =>
                    _int(h['cari_id']) ==
                    cariId,
              )
              .toList()
            ..sort((a, b) {
              final ta =
                  DateTime.tryParse(
                    a['tarih']
                            ?.toString() ??
                        '',
                  ) ??
                  DateTime(2000);

              final tb =
                  DateTime.tryParse(
                    b['tarih']
                            ?.toString() ??
                        '',
                  ) ??
                  DateTime(2000);

              return ta.compareTo(tb);
            });

      final borclar =
          <Map<String, dynamic>>[];

      final alacaklar =
          <Map<String, dynamic>>[];

      for (final h in hareketler) {
        final tarih =
            DateTime.tryParse(
              h['tarih']?.toString() ?? '',
            )?.toLocal();

        final borc =
            _sayi(h['borc']);

        final alacak =
            _sayi(h['alacak']);

        if (borc > 0) {
          borclar.add({
            'tarih': tarih,
            'kalan': borc,
          });
        }

        if (alacak > 0) {
          alacaklar.add({
            'tarih': tarih,
            'kalan': alacak,
          });
        }
      }

      void mahsuplastir(
        List<Map<String, dynamic>> aciklar,
        List<Map<String, dynamic>> kapatanlar,
      ) {
        int i = 0;
        int j = 0;

        while (i < aciklar.length &&
            j < kapatanlar.length) {
          final acik =
              _sayi(aciklar[i]['kalan']);

          final kapatan =
              _sayi(
            kapatanlar[j]['kalan'],
          );

          if (acik <= 0) {
            i++;
            continue;
          }

          if (kapatan <= 0) {
            j++;
            continue;
          }

          final mahsup =
              acik < kapatan
                  ? acik
                  : kapatan;

          aciklar[i]['kalan'] =
              acik - mahsup;

          kapatanlar[j]['kalan'] =
              kapatan - mahsup;
        }
      }

      // FIFO: eski borç önce kapanır.
      mahsuplastir(
        borclar,
        alacaklar,
      );

      final sonuc =
          <String, double>{
        '0-30': 0,
        '31-60': 0,
        '61-90': 0,
        '90+': 0,
        'toplam': 0,
      };

      for (final item in borclar) {
        final kalan =
            _sayi(item['kalan']);

        if (kalan <= 0) continue;

        final tarih =
            item['tarih'] as DateTime?;

        final gun =
            tarih == null
                ? 9999
                : bugun
                    .difference(tarih)
                    .inDays
                    .clamp(0, 99999);

        if (gun <= 30) {
          sonuc['0-30'] =
              (sonuc['0-30'] ?? 0) +
                  kalan;
        } else if (gun <= 60) {
          sonuc['31-60'] =
              (sonuc['31-60'] ?? 0) +
                  kalan;
        } else if (gun <= 90) {
          sonuc['61-90'] =
              (sonuc['61-90'] ?? 0) +
                  kalan;
        } else {
          sonuc['90+'] =
              (sonuc['90+'] ?? 0) +
                  kalan;
        }

        sonuc['toplam'] =
            (sonuc['toplam'] ?? 0) +
                kalan;
      }

      return sonuc;
    }

    double toplamPozitif = 0;
    double toplamNegatif = 0;
    double toplamRisk = 0;

    int riskAsimi = 0;
    int aktifCari = 0;

    double yas0_30 = 0;
    double yas31_60 = 0;
    double yas61_90 = 0;
    double yas90 = 0;

    final cariYaslandirma =
        <int, Map<String, double>>{};

    for (final cari in cariler) {
      final cariId =
          _int(cari['cari_id']);

      final bakiye =
          _sayi(cari['bakiye']);

      final risk =
          _sayi(cari['risk_limiti']);

      final aktif =
          cari['aktif']
              ?.toString()
              .toLowerCase();

      if (aktif == null ||
          aktif == 'true' ||
          aktif == '1' ||
          aktif == 'aktif' ||
          aktif == 'evet') {
        aktifCari++;
      }

      if (bakiye > 0) {
        toplamPozitif += bakiye;
      }

      if (bakiye < 0) {
        toplamNegatif +=
            bakiye.abs();
      }

      toplamRisk += risk;

      if (risk > 0 &&
          bakiye.abs() > risk) {
        riskAsimi++;
      }

      if (cariId != null) {
        final yas =
            yaslandirma(cariId);

        cariYaslandirma[cariId] =
            yas;

        yas0_30 +=
            yas['0-30'] ?? 0;

        yas31_60 +=
            yas['31-60'] ?? 0;

        yas61_90 +=
            yas['61-90'] ?? 0;

        yas90 +=
            yas['90+'] ?? 0;
      }
    }

    final netCari =
        toplamPozitif -
            toplamNegatif;

    final toplamAcik =
        yas0_30 +
            yas31_60 +
            yas61_90 +
            yas90;

    cariler.sort((a, b) {
      final aBakiye =
          _sayi(a['bakiye']).abs();

      final bBakiye =
          _sayi(b['bakiye']).abs();

      return bBakiye.compareTo(
        aBakiye,
      );
    });

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.all(12),
          child: MobilYatayRow(
            children: [
              Expanded(
                child: TextField(
                  controller:
                      _aramaController,
                  decoration:
                      InputDecoration(
                    hintText:
                        'Cari ünvanı veya tipi...',
                    prefixIcon:
                        const Icon(
                      Icons.search,
                    ),
                    suffixIcon:
                        _aramaController
                                .text.isEmpty
                            ? null
                            : IconButton(
                                onPressed:
                                    _aramaController
                                        .clear,
                                icon:
                                    const Icon(
                                  Icons.clear,
                                ),
                              ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Chip(
                avatar: Icon(
                  Icons.history,
                  size: 18,
                ),
                label: Text(
                  'Yaşlandırma: Tüm Cari Geçmişi',
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Yenile',
                onPressed:
                    _verileriYukle,
                icon: const Icon(
                  Icons.refresh,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            0,
          ),
          child: MobilYatayRow(
            children: [
              _ozetKarti(
                baslik:
                    'Cari / Aktif',
                deger:
                    '${cariler.length} / $aktifCari',
                ikon: Icons.people,
                renk: Colors.blue,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Toplam Pozitif',
                deger:
                    _para(toplamPozitif),
                ikon:
                    Icons.trending_up,
                renk: Colors.green,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Toplam Negatif',
                deger:
                    _para(toplamNegatif),
                ikon:
                    Icons.trending_down,
                renk: Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik: 'Net Cari',
                deger:
                    _para(netCari),
                ikon:
                    Icons.balance,
                renk: netCari >= 0
                    ? Colors.teal
                    : Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Risk Aşımı',
                deger:
                    '$riskAsimi Cari',
                ikon:
                    Icons.warning_amber,
                renk: Colors.orange,
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            4,
            12,
            0,
          ),
          child: MobilYatayRow(
            children: [
              _ozetKarti(
                baslik:
                    '0 - 30 Gün',
                deger:
                    _para(yas0_30),
                ikon:
                    Icons.schedule,
                renk: Colors.green,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    '31 - 60 Gün',
                deger:
                    _para(yas31_60),
                ikon:
                    Icons.schedule,
                renk: Colors.amber,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    '61 - 90 Gün',
                deger:
                    _para(yas61_90),
                ikon:
                    Icons.schedule,
                renk: Colors.orange,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    '90+ Gün',
                deger:
                    _para(yas90),
                ikon:
                    Icons.timer_off,
                renk: Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Açık Yaşlandırma',
                deger:
                    _para(toplamAcik),
                ikon:
                    Icons.query_stats,
                renk:
                    Colors.deepPurple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: cariler.isEmpty
              ? const Center(
                  child: Text(
                    'Cari bulunamadı.',
                  ),
                )
              : Card(
                  margin:
                      const EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    12,
                  ),
                  child:
                      SingleChildScrollView(
                    scrollDirection:
                        Axis.horizontal,
                    child: SingleChildScrollView(
                      child: MobilTablo(
                                  child: DataTable(
                        headingRowColor:
                            MaterialStatePropertyAll(
                          Colors
                              .blueGrey
                              .shade50,
                        ),
                        columns: const [
                          DataColumn(
                            label:
                                Text('Cari'),
                          ),
                          DataColumn(
                            label:
                                Text('Tip'),
                          ),
                          DataColumn(
                            numeric: true,
                            label:
                                Text('Bakiye'),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              'Risk Limiti',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              '0-30',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              '31-60',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text(
                              '61-90',
                            ),
                          ),
                          DataColumn(
                            numeric: true,
                            label:
                                Text('90+'),
                          ),
                          DataColumn(
                            label:
                                Text('Durum'),
                          ),
                        ],
                        rows: cariler.map(
                          (cari) {
                            final cariId =
                                _int(
                              cari['cari_id'],
                            );

                            final bakiye =
                                _sayi(
                              cari['bakiye'],
                            );

                            final risk =
                                _sayi(
                              cari[
                                  'risk_limiti'],
                            );

                            final riskAsildi =
                                risk > 0 &&
                                    bakiye
                                            .abs() >
                                        risk;

                            final yas =
                                cariId == null
                                    ? <String,
                                        double>{}
                                    : cariYaslandirma[
                                            cariId] ??
                                        <String,
                                            double>{};

                            final gecikmis =
                                (yas['90+'] ??
                                        0) >
                                    0;

                            return DataRow(
                              color:
                                  MaterialStateProperty
                                      .resolveWith(
                                (states) {
                                  if (riskAsildi) {
                                    return Colors
                                        .red
                                        .withOpacity(
                                      0.05,
                                    );
                                  }

                                  if (gecikmis) {
                                    return Colors
                                        .orange
                                        .withOpacity(
                                      0.04,
                                    );
                                  }

                                  return null;
                                },
                              ),
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 300,
                                    child: Text(
                                      _metin(
                                        cari[
                                            'unvan'],
                                      ),
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _metin(
                                      cari[
                                          'cari_tipi'],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      bakiye
                                          .abs(),
                                    ),
                                    style:
                                        TextStyle(
                                      color:
                                          bakiye > 0
                                              ? Colors
                                                  .green
                                              : bakiye <
                                                      0
                                                  ? Colors
                                                      .red
                                                  : Colors
                                                      .grey,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(risk),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      yas['0-30'] ??
                                          0,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      yas['31-60'] ??
                                          0,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      yas['61-90'] ??
                                          0,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _para(
                                      yas['90+'] ??
                                          0,
                                    ),
                                    style:
                                        TextStyle(
                                      color:
                                          (yas['90+'] ??
                                                      0) >
                                                  0
                                              ? Colors
                                                  .red
                                              : Colors
                                                  .grey,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    riskAsildi
                                        ? 'RİSK AŞIMI'
                                        : gecikmis
                                            ? '90+ GECİKMİŞ'
                                            : bakiye ==
                                                    0
                                                ? 'KAPALI'
                                                : 'NORMAL',
                                    style:
                                        TextStyle(
                                      color:
                                          riskAsildi
                                              ? Colors
                                                  .red
                                              : gecikmis
                                                  ? Colors
                                                      .orange
                                                  : bakiye ==
                                                          0
                                                      ? Colors
                                                          .grey
                                                      : Colors
                                                          .green,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ).toList(),
                      ),
                                ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _kasaRaporu() {
    final arama =
        _aramaController.text.toLowerCase().trim();

    bool girisMi(Map<String, dynamic> hareket) {
      final tip =
          _metin(hareket['tip']).toUpperCase();

      return tip == 'GIRIS' ||
          tip == 'GİRİŞ';
    }

    final hareketler =
        _kasaHareketler.where((hareket) {
      if (arama.isEmpty) return true;

      final metin = [
        _kasaAdi(hareket['kasa_id']),
        _cariAdi(hareket['cari_id']),
        hareket['belge_no'],
        hareket['aciklama'],
        hareket['kullanici'],
        hareket['tip'],
      ]
          .map((e) => e?.toString() ?? '')
          .join(' ')
          .toLowerCase();

      return arama
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .every(metin.contains);
    }).toList();

    double donemGiris = 0;
    double donemCikis = 0;

    final donemHesapNet =
        <int, double>{};

    final donemHesapGiris =
        <int, double>{};

    final donemHesapCikis =
        <int, double>{};

    for (final hareket in hareketler) {
      final tutar =
          _sayi(hareket['tutar']);

      final kasaId =
          _int(hareket['kasa_id']);

      final isGiris =
          girisMi(hareket);

      if (isGiris) {
        donemGiris += tutar;
      } else {
        donemCikis += tutar;
      }

      if (kasaId != null) {
        donemHesapNet[kasaId] =
            (donemHesapNet[kasaId] ?? 0) +
                (isGiris ? tutar : -tutar);

        if (isGiris) {
          donemHesapGiris[kasaId] =
              (donemHesapGiris[kasaId] ?? 0) +
                  tutar;
        } else {
          donemHesapCikis[kasaId] =
              (donemHesapCikis[kasaId] ?? 0) +
                  tutar;
        }
      }
    }

    final guncelBakiyeler =
        <int, double>{};

    for (final hareket
        in _tumKasaHareketler) {
      final kasaId =
          _int(hareket['kasa_id']);

      if (kasaId == null) continue;

      final tutar =
          _sayi(hareket['tutar']);

      guncelBakiyeler[kasaId] =
          (guncelBakiyeler[kasaId] ?? 0) +
              (girisMi(hareket)
                  ? tutar
                  : -tutar);
    }

    double toplamGuncelBakiye = 0;
    double nakitBakiye = 0;
    double bankaBakiye = 0;
    double posBakiye = 0;
    double krediKartiBakiye = 0;

    for (final kasa in _kasalar) {
      final kasaId =
          _int(kasa['kasa_id']);

      if (kasaId == null) continue;

      final bakiye =
          guncelBakiyeler[kasaId] ?? 0;

      toplamGuncelBakiye += bakiye;

      final tip =
          _metin(kasa['kasa_tipi'])
              .toUpperCase();

      final ad =
          _metin(kasa['kasa_adi'])
              .toUpperCase();

      if (tip.contains('POS') ||
          ad.contains('POS')) {
        posBakiye += bakiye;
      } else if (tip.contains('KRED') ||
          tip.contains('K.K') ||
          ad.contains('K.K') ||
          ad.contains('KREDİ') ||
          ad.contains('KREDI')) {
        krediKartiBakiye += bakiye;
      } else if (tip.contains('BANK') ||
          ad.contains('BANK') ||
          ad.contains('HESAP')) {
        bankaBakiye += bakiye;
      } else {
        nakitBakiye += bakiye;
      }
    }

    final netDonem =
        donemGiris - donemCikis;

    final hesapSiralamasi =
        _kasalar.toList()
          ..sort((a, b) {
            final aId =
                _int(a['kasa_id']);

            final bId =
                _int(b['kasa_id']);

            final aBakiye =
                aId == null
                    ? 0.0
                    : (guncelBakiyeler[
                            aId] ??
                        0)
                        .abs();

            final bBakiye =
                bId == null
                    ? 0.0
                    : (guncelBakiyeler[
                            bId] ??
                        0)
                        .abs();

            return bBakiye.compareTo(
              aBakiye,
            );
          });

    final enCokGiris =
        donemHesapGiris.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(a.value),
          );

    final enCokCikis =
        donemHesapCikis.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(a.value),
          );

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.all(12),
          child: MobilYatayRow(
            children: [
              Expanded(
                child: TextField(
                  controller:
                      _aramaController,
                  decoration:
                      InputDecoration(
                    hintText:
                        'Kasa, banka, POS, cari, belge no, açıklama...',
                    prefixIcon:
                        const Icon(
                      Icons.search,
                    ),
                    suffixIcon:
                        _aramaController
                                .text.isEmpty
                            ? null
                            : IconButton(
                                onPressed:
                                    _aramaController
                                        .clear,
                                icon:
                                    const Icon(
                                  Icons.clear,
                                ),
                              ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    _tarihSec(
                  baslangic: true,
                ),
                icon: const Icon(
                  Icons.calendar_today,
                ),
                label: Text(
                  'Başlangıç: ${_kisaTarih(_baslangic)}',
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _tarihSec(
                  baslangic: false,
                ),
                icon:
                    const Icon(Icons.event),
                label: Text(
                  'Bitiş: ${_kisaTarih(_bitis)}',
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Yenile',
                onPressed:
                    _verileriYukle,
                icon: const Icon(
                  Icons.refresh,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            0,
          ),
          child: MobilYatayRow(
            children: [
              _ozetKarti(
                baslik:
                    'Dönem Giriş',
                deger:
                    _para(donemGiris),
                ikon:
                    Icons.south_west,
                renk: Colors.green,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Dönem Çıkış',
                deger:
                    _para(donemCikis),
                ikon:
                    Icons.north_east,
                renk: Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Dönem Net',
                deger:
                    _para(netDonem),
                ikon:
                    Icons.swap_horiz,
                renk: netDonem >= 0
                    ? Colors.teal
                    : Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Güncel Toplam Bakiye',
                deger:
                    _para(
                  toplamGuncelBakiye,
                ),
                ikon:
                    Icons.account_balance_wallet,
                renk:
                    toplamGuncelBakiye >=
                            0
                        ? Colors.blue
                        : Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Hareket Sayısı',
                deger:
                    '${hareketler.length}',
                ikon:
                    Icons.receipt_long,
                renk:
                    Colors.deepPurple,
              ),
            ],
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            4,
            12,
            0,
          ),
          child: MobilYatayRow(
            children: [
              _ozetKarti(
                baslik:
                    'Nakit / Kasa',
                deger:
                    _para(nakitBakiye),
                ikon:
                    Icons.payments,
                renk:
                    nakitBakiye >= 0
                        ? Colors.green
                        : Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik: 'Banka',
                deger:
                    _para(bankaBakiye),
                ikon:
                    Icons.account_balance,
                renk:
                    bankaBakiye >= 0
                        ? Colors.blue
                        : Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik: 'POS',
                deger:
                    _para(posBakiye),
                ikon:
                    Icons.point_of_sale,
                renk:
                    posBakiye >= 0
                        ? Colors.teal
                        : Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Kredi Kartları',
                deger:
                    _para(
                  krediKartiBakiye,
                ),
                ikon:
                    Icons.credit_card,
                renk:
                    krediKartiBakiye >= 0
                        ? Colors.indigo
                        : Colors.red,
              ),
              const SizedBox(width: 8),
              _ozetKarti(
                baslik:
                    'Hesap Sayısı',
                deger:
                    '${_kasalar.length}',
                ikon:
                    Icons.account_balance_wallet_outlined,
                renk: Colors.orange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 145,
          child: MobilYatayRow(
            children: [
              Expanded(
                child: Card(
                  margin:
                      const EdgeInsets.only(
                    left: 12,
                    right: 4,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'En Çok Giriş Olan Hesaplar',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Expanded(
                          child: enCokGiris
                                  .isEmpty
                              ? const Center(
                                  child: Text(
                                    'Veri yok',
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      enCokGiris
                                          .take(5)
                                          .length,
                                  itemBuilder:
                                      (_, index) {
                                    final item =
                                        enCokGiris[
                                            index];

                                    return MobilYatayRow(
                                      children: [
                                        Expanded(
                                          child:
                                              Text(
                                            '${index + 1}. ${_kasaAdi(item.key)}',
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                        ),
                                        Text(
                                          _para(
                                            item.value,
                                          ),
                                          style:
                                              const TextStyle(
                                            color:
                                                Colors.green,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  margin:
                      const EdgeInsets.only(
                    left: 4,
                    right: 12,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'En Çok Çıkış Olan Hesaplar',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Expanded(
                          child: enCokCikis
                                  .isEmpty
                              ? const Center(
                                  child: Text(
                                    'Veri yok',
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      enCokCikis
                                          .take(5)
                                          .length,
                                  itemBuilder:
                                      (_, index) {
                                    final item =
                                        enCokCikis[
                                            index];

                                    return MobilYatayRow(
                                      children: [
                                        Expanded(
                                          child:
                                              Text(
                                            '${index + 1}. ${_kasaAdi(item.key)}',
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                          ),
                                        ),
                                        Text(
                                          _para(
                                            item.value,
                                          ),
                                          style:
                                              const TextStyle(
                                            color:
                                                Colors.red,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 145,
          child: ListView.separated(
            scrollDirection:
                Axis.horizontal,
            padding:
                const EdgeInsets.fromLTRB(
              12,
              6,
              12,
              6,
            ),
            itemCount:
                hesapSiralamasi.length,
            separatorBuilder:
                (_, __) =>
                    const SizedBox(
              width: 8,
            ),
            itemBuilder:
                (context, index) {
              final kasa =
                  hesapSiralamasi[index];

              final kasaId =
                  _int(kasa['kasa_id']);

              final guncel =
                  kasaId == null
                      ? 0.0
                      : (guncelBakiyeler[
                              kasaId] ??
                          0.0);

              final donem =
                  kasaId == null
                      ? 0.0
                      : (donemHesapNet[
                              kasaId] ??
                          0.0);

              return SizedBox(
                width: 270,
                child: Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          _metin(
                            kasa['kasa_adi'],
                          ),
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          'Tip: ${_metin(kasa['kasa_tipi'])}',
                          style:
                              const TextStyle(
                            fontSize: 11,
                            color:
                                Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Güncel: ${_para(guncel)}',
                          style:
                              TextStyle(
                            color: guncel >= 0
                                ? Colors.blue
                                : Colors.red,
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        Text(
                          'Dönem Net: ${donem >= 0 ? '+' : ''}${_para(donem)}',
                          style:
                              TextStyle(
                            color: donem >= 0
                                ? Colors.green
                                : Colors.red,
                            fontSize: 12,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: hareketler.isEmpty
              ? const Center(
                  child: Text(
                    'Kasa / banka hareketi bulunamadı.',
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  itemCount:
                      hareketler.length,
                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    height: 8,
                  ),
                  itemBuilder:
                      (context, index) {
                    final hareket =
                        hareketler[index];

                    final isGiris =
                        girisMi(hareket);

                    return Card(
                      child: ListTile(
                        leading:
                            CircleAvatar(
                          backgroundColor:
                              (isGiris
                                      ? Colors
                                          .green
                                      : Colors.red)
                                  .withOpacity(
                            0.14,
                          ),
                          child: Icon(
                            isGiris
                                ? Icons
                                    .south_west
                                : Icons
                                    .north_east,
                            color: isGiris
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        title: Text(
                          _kasaAdi(
                            hareket[
                                'kasa_id'],
                          ),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        subtitle: Text(
                          'Cari: ${_cariAdi(hareket['cari_id'])}\n'
                          'Belge: ${_metin(hareket['belge_no'])} • '
                          '${_tarih(hareket['tarih'])}\n'
                          '${_metin(hareket['aciklama'])} • '
                          'Kullanıcı: ${_metin(hareket['kullanici'])}',
                        ),
                        trailing:
                            SizedBox(
                          width: 170,
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .end,
                            children: [
                              Text(
                                '${isGiris ? '+' : '-'}${_para(hareket['tutar'])}',
                                style:
                                    TextStyle(
                                  color: isGiris
                                      ? Colors
                                          .green
                                      : Colors
                                          .red,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                isGiris
                                    ? 'GİRİŞ'
                                    : 'ÇIKIŞ',
                                style:
                                    TextStyle(
                                  color: isGiris
                                      ? Colors
                                          .green
                                      : Colors
                                          .red,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _grafikler() {
    final aylikSatis =
        <int, double>{};

    final aylikAlis =
        <int, double>{};

    final aylikKar =
        <int, double>{};

    final aylikMaliyet =
        <int, double>{};

    final aylikGider =
        <int, double>{};

    final aylikNetKar =
        <int, double>{};

    double toplamSatis = 0;
    double toplamAlis = 0;
    double toplamKar = 0;
    double toplamSatisMaliyeti = 0;
    double toplamIsletmeGideri = 0;

    final gecerliSatisIdleri =
        <int>{};

    for (final satis in _satislar) {
      if (_iptalMi(satis['durum'])) {
        continue;
      }

      final satisId =
          _int(satis['satis_id']);

      if (satisId != null) {
        gecerliSatisIdleri.add(
          satisId,
        );
      }

      final tarih =
          DateTime.tryParse(
        satis['tarih']?.toString() ??
            '',
      )?.toLocal();

      if (tarih == null) {
        continue;
      }

      final tutar =
          _sayi(
        satis['genel_toplam'],
      );

      final satisKar =
          _satisKar(
        satis['satis_id'],
      );

      final maliyet =
          tutar - satisKar;

      toplamSatis += tutar;
      toplamKar += satisKar;
      toplamSatisMaliyeti += maliyet;

      aylikSatis[tarih.month] =
          (aylikSatis[tarih.month] ??
                  0) +
              tutar;

      aylikKar[tarih.month] =
          (aylikKar[tarih.month] ??
                  0) +
              satisKar;

      aylikMaliyet[tarih.month] =
          (aylikMaliyet[
                      tarih.month] ??
                  0) +
              maliyet;
    }

    for (final alis in _alislar) {
      if (_iptalMi(alis['durum'])) {
        continue;
      }

      final tarih =
          DateTime.tryParse(
        alis['tarih']?.toString() ??
            '',
      )?.toLocal();

      if (tarih == null) {
        continue;
      }

      final tutar =
          _sayi(
        alis['genel_toplam'],
      );

      toplamAlis += tutar;

      aylikAlis[tarih.month] =
          (aylikAlis[tarih.month] ??
                  0) +
              tutar;
    }

    for (final gider in _giderler) {
      final iptal =
          gider['iptal'] == true ||
              gider['iptal']
                      ?.toString()
                      .toLowerCase() ==
                  'true';

      if (iptal) continue;

      final tarih =
          DateTime.tryParse(
        gider['tarih']?.toString() ??
            '',
      )?.toLocal();

      if (tarih == null) {
        continue;
      }

      final tutar =
          _sayi(gider['tutar']);

      toplamIsletmeGideri += tutar;

      aylikGider[tarih.month] =
          (aylikGider[tarih.month] ??
                  0) +
              tutar;
    }

    for (var ay = 1; ay <= 12; ay++) {
      aylikNetKar[ay] =
          (aylikKar[ay] ?? 0) -
              (aylikGider[ay] ?? 0);
    }

    final netKar =
        toplamKar - toplamIsletmeGideri;

    final netKarMarji =
        toplamSatis <= 0
            ? 0.0
            : netKar /
                toplamSatis *
                100;

    final netNakitAkisi =
        toplamSatis -
            toplamAlis -
            toplamIsletmeGideri;

    final karMarji =
        toplamSatis <= 0
            ? 0.0
            : toplamKar /
                toplamSatis *
                100;

    final urunSatislari =
        <int, Map<String, double>>{};

    for (final detay in _satisDetaylar) {
      final satisId =
          _int(detay['satis_id']);

      if (satisId == null ||
          !gecerliSatisIdleri
              .contains(satisId)) {
        continue;
      }

      final stokId =
          _int(detay['stok_id']);

      if (stokId == null) {
        continue;
      }

      final miktar =
          _sayi(detay['miktar']);

      final birimFiyat =
          _sayi(
        detay['birim_fiyat'],
      );

      final indirim =
          _sayi(detay['indirim']);

      final netBirim =
          birimFiyat *
              (1 - indirim / 100);

      var alisFiyati =
          _sayi(
        detay['alis_fiyati'],
      );

      if (alisFiyati <= 0) {
        for (final stok in _stoklar) {
          if (_int(stok['stok_id']) ==
              stokId) {
            alisFiyati =
                _sayi(
              stok['alis_fiyati'],
            );
            break;
          }
        }
      }

      final ciro =
          miktar * netBirim;

      final maliyet =
          miktar * alisFiyati;

      final ozet =
          urunSatislari.putIfAbsent(
        stokId,
        () => {
          'miktar': 0,
          'ciro': 0,
          'kar': 0,
        },
      );

      ozet['miktar'] =
          (ozet['miktar'] ?? 0) +
              miktar;

      ozet['ciro'] =
          (ozet['ciro'] ?? 0) +
              ciro;

      ozet['kar'] =
          (ozet['kar'] ?? 0) +
              (ciro - maliyet);
    }

    final enCokSatanlar =
        urunSatislari.entries.toList()
          ..sort(
            (a, b) =>
                (b.value['miktar'] ??
                        0)
                    .compareTo(
              a.value['miktar'] ??
                  0,
            ),
          );

    final enKarliUrunler =
        urunSatislari.entries.toList()
          ..sort(
            (a, b) =>
                (b.value['kar'] ?? 0)
                    .compareTo(
              a.value['kar'] ?? 0,
            ),
          );

    final cariCiro =
        <int, double>{};

    for (final satis in _satislar) {
      if (_iptalMi(satis['durum'])) {
        continue;
      }

      final cariId =
          _int(satis['cari_id']);

      if (cariId == null) continue;

      cariCiro[cariId] =
          (cariCiro[cariId] ?? 0) +
              _sayi(
                satis[
                    'genel_toplam'],
              );
    }

    final enIyiCariler =
        cariCiro.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(
              a.value,
            ),
          );

    final maxBar = [
      ...aylikSatis.values,
      ...aylikAlis.values,
      1.0,
    ].reduce(
      (a, b) => a > b ? a : b,
    );

    final maxKarMutlak = [
      ...aylikKar.values
          .map((e) => e.abs()),
      ...aylikNetKar.values
          .map((e) => e.abs()),
      ...aylikGider.values
          .map((e) => e.abs()),
      1.0,
    ].reduce(
      (a, b) => a > b ? a : b,
    );

    const aylar = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];

    return ListView(
      padding:
          const EdgeInsets.all(12),
      children: [
        MobilYatayRow(
          children: [
            _ozetKarti(
              baslik:
                  'Toplam Satış',
              deger:
                  _para(toplamSatis),
              ikon:
                  Icons.trending_up,
              renk: Colors.green,
            ),
            const SizedBox(width: 8),
            _ozetKarti(
              baslik:
                  'Toplam Alış',
              deger:
                  _para(toplamAlis),
              ikon:
                  Icons.shopping_cart,
              renk: Colors.blue,
            ),
            const SizedBox(width: 8),
            _ozetKarti(
              baslik:
                  'Satış Maliyeti',
              deger:
                  _para(
                toplamSatisMaliyeti,
              ),
              ikon:
                  Icons.price_check,
              renk: Colors.orange,
            ),
            const SizedBox(width: 8),
            _ozetKarti(
              baslik:
                  'Brüt Kâr',
              deger:
                  '${_para(toplamKar)}  (%${karMarji.toStringAsFixed(1)})',
              ikon:
                  Icons.auto_graph,
              renk: toplamKar >= 0
                  ? Colors.teal
                  : Colors.red,
            ),
            const SizedBox(width: 8),
            _ozetKarti(
              baslik:
                  'İşletme Giderleri',
              deger:
                  _para(toplamIsletmeGideri),
              ikon:
                  Icons.receipt_long,
              renk: Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 6),
        MobilYatayRow(
          children: [
            _ozetKarti(
              baslik: 'NET KÂR / ZARAR',
              deger:
                  '${_para(netKar)}  (%${netKarMarji.toStringAsFixed(1)})',
              ikon:
                  netKar >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
              renk: netKar >= 0
                  ? Colors.green
                  : Colors.red,
            ),
            const SizedBox(width: 8),
            _ozetKarti(
              baslik: 'Satış - Alış - Gider',
              deger:
                  _para(netNakitAkisi),
              ikon:
                  Icons.compare_arrows,
              renk: netNakitAkisi >= 0
                  ? Colors.deepPurple
                  : Colors.red,
            ),
            const SizedBox(width: 8),
            _ozetKarti(
              baslik: 'Gider Kayıt Sayısı',
              deger:
                  '${_giderler.where((g) => !(g['iptal'] == true || g['iptal']?.toString().toLowerCase() == 'true')).length}',
              ikon:
                  Icons.description_outlined,
              renk: Colors.orange,
            ),
            const SizedBox(width: 8),
            _ozetKarti(
              baslik: 'Net Kâr Marjı',
              deger:
                  '%${netKarMarji.toStringAsFixed(2)}',
              ikon:
                  Icons.percent,
              renk: netKarMarji >= 0
                  ? Colors.teal
                  : Colors.red,
            ),
            const SizedBox(width: 8),
            _ozetKarti(
              baslik: 'Dönem',
              deger:
                  '${_kisaTarih(_baslangic)} - ${_kisaTarih(_bitis)}',
              ikon:
                  Icons.calendar_month,
              renk: Colors.blueGrey,
            ),
          ],
        ),
        const SizedBox(height: 12),
        MobilYatayRow(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Aylık Satış / Alış Karşılaştırması',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        '${_kisaTarih(_baslangic)} - ${_kisaTarih(_bitis)}',
                        style:
                            const TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      SizedBox(
                        height: 320,
                        child: BarChart(
                          BarChartData(
                            alignment:
                                BarChartAlignment
                                    .spaceAround,
                            maxY:
                                maxBar * 1.15,
                            titlesData:
                                FlTitlesData(
                              topTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      false,
                                ),
                              ),
                              rightTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      false,
                                ),
                              ),
                              bottomTitles:
                                  AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      true,
                                  getTitlesWidget:
                                      (value,
                                          meta) {
                                    final ay =
                                        value
                                            .toInt();

                                    if (ay < 1 ||
                                        ay >
                                            12) {
                                      return const SizedBox
                                          .shrink();
                                    }

                                    return Text(
                                      aylar[
                                          ay],
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups:
                                List.generate(
                              12,
                              (index) {
                                final ay =
                                    index + 1;

                                return BarChartGroupData(
                                  x: ay,
                                  barRods: [
                                    BarChartRodData(
                                      toY:
                                          aylikSatis[
                                                  ay] ??
                                              0,
                                      width:
                                          8,
                                      color:
                                          Colors
                                              .green,
                                    ),
                                    BarChartRodData(
                                      toY:
                                          aylikAlis[
                                                  ay] ??
                                              0,
                                      width:
                                          8,
                                      color:
                                          Colors
                                              .blue,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      const MobilYatayRow(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 11,
                            color:
                                Colors.green,
                          ),
                          SizedBox(
                            width: 5,
                          ),
                          Text('Satış'),
                          SizedBox(
                            width: 18,
                          ),
                          Icon(
                            Icons.circle,
                            size: 11,
                            color:
                                Colors.blue,
                          ),
                          SizedBox(
                            width: 5,
                          ),
                          Text('Alış'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Aylık Brüt Kâr / Gider / Net Kâr',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      const Text(
                        'Net Kâr = Brüt Kâr - İşletme Giderleri',
                        style: TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      SizedBox(
                        height: 320,
                        child: LineChart(
                          LineChartData(
                            minY:
                                -maxKarMutlak *
                                    1.15,
                            maxY:
                                maxKarMutlak *
                                    1.15,
                            gridData:
                                const FlGridData(
                              show: true,
                            ),
                            borderData:
                                FlBorderData(
                              show: true,
                            ),
                            titlesData:
                                FlTitlesData(
                              topTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      false,
                                ),
                              ),
                              rightTitles:
                                  const AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      false,
                                ),
                              ),
                              bottomTitles:
                                  AxisTitles(
                                sideTitles:
                                    SideTitles(
                                  showTitles:
                                      true,
                                  getTitlesWidget:
                                      (value,
                                          meta) {
                                    final ay =
                                        value
                                            .toInt();

                                    if (ay < 1 ||
                                        ay >
                                            12) {
                                      return const SizedBox
                                          .shrink();
                                    }

                                    return Text(
                                      aylar[
                                          ay],
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                isCurved: true,
                                barWidth: 2,
                                color: Colors.teal,
                                dotData:
                                    const FlDotData(
                                  show: true,
                                ),
                                spots:
                                    List.generate(
                                  12,
                                  (index) {
                                    final ay =
                                        index + 1;
                                    return FlSpot(
                                      ay.toDouble(),
                                      aylikKar[ay] ??
                                          0,
                                    );
                                  },
                                ),
                              ),
                              LineChartBarData(
                                isCurved: true,
                                barWidth: 2,
                                color: Colors.red,
                                dotData:
                                    const FlDotData(
                                  show: true,
                                ),
                                spots:
                                    List.generate(
                                  12,
                                  (index) {
                                    final ay =
                                        index + 1;
                                    return FlSpot(
                                      ay.toDouble(),
                                      aylikGider[ay] ??
                                          0,
                                    );
                                  },
                                ),
                              ),
                              LineChartBarData(
                                isCurved: true,
                                barWidth: 3,
                                color: Colors.green,
                                dotData:
                                    const FlDotData(
                                  show: true,
                                ),
                                spots:
                                    List.generate(
                                  12,
                                  (index) {
                                    final ay =
                                        index + 1;
                                    return FlSpot(
                                      ay.toDouble(),
                                      aylikNetKar[ay] ??
                                          0,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MobilYatayRow(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _analizListeKarti(
                baslik:
                    'En Çok Satan 10 Ürün',
                ikon:
                    Icons.inventory_2,
                satirlar:
                    enCokSatanlar
                        .take(10)
                        .map(
                          (e) =>
                              '${_stokAdi(e.key)}|${(e.value['miktar'] ?? 0).toStringAsFixed(0)} Adet',
                        )
                        .toList(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _analizListeKarti(
                baslik:
                    'En Kârlı 10 Ürün',
                ikon:
                    Icons.trending_up,
                satirlar:
                    enKarliUrunler
                        .take(10)
                        .map(
                          (e) =>
                              '${_stokAdi(e.key)}|${_para(e.value['kar'] ?? 0)}',
                        )
                        .toList(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _analizListeKarti(
                baslik:
                    'En Çok Ciro Yapan 10 Cari',
                ikon:
                    Icons.people,
                satirlar:
                    enIyiCariler
                        .take(10)
                        .map(
                          (e) =>
                              '${_cariAdi(e.key)}|${_para(e.value)}',
                        )
                        .toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kâr / Zarar Özeti',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                MobilTablo(
                                  child: DataTable(
                  columns: const [
                    DataColumn(
                      label:
                          Text('Kalem'),
                    ),
                    DataColumn(
                      numeric: true,
                      label:
                          Text('Tutar'),
                    ),
                  ],
                  rows: [
                    DataRow(
                      cells: [
                        const DataCell(
                          Text(
                            'Net Satış Cirosu',
                          ),
                        ),
                        DataCell(
                          Text(
                            _para(
                              toplamSatis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    DataRow(
                      cells: [
                        const DataCell(
                          Text(
                            'Satılan Mal Maliyeti',
                          ),
                        ),
                        DataCell(
                          Text(
                            '-${_para(toplamSatisMaliyeti)}',
                          ),
                        ),
                      ],
                    ),
                    DataRow(
                      cells: [
                        const DataCell(
                          Text(
                            'Gerçekleşen Brüt Kâr',
                          ),
                        ),
                        DataCell(
                          Text(
                            _para(
                              toplamKar,
                            ),
                            style:
                                TextStyle(
                              color:
                                  toplamKar >=
                                          0
                                      ? Colors
                                          .teal
                                      : Colors
                                          .red,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    DataRow(
                      cells: [
                        const DataCell(
                          Text(
                            'İşletme Giderleri',
                          ),
                        ),
                        DataCell(
                          Text(
                            '-${_para(toplamIsletmeGideri)}',
                            style:
                                const TextStyle(
                              color: Colors.red,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    DataRow(
                      cells: [
                        const DataCell(
                          Text(
                            'NET KÂR / ZARAR',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _para(netKar),
                            style:
                                TextStyle(
                              color: netKar >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    DataRow(
                      cells: [
                        const DataCell(
                          Text(
                            'Dönem Mal Alışı',
                          ),
                        ),
                        DataCell(
                          Text(
                            _para(
                              toplamAlis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    DataRow(
                      cells: [
                        const DataCell(
                          Text(
                            'Satış - Alış Nakit Farkı',
                          ),
                        ),
                        DataCell(
                          Text(
                            _para(
                              netNakitAkisi,
                            ),
                            style:
                                TextStyle(
                              color:
                                  netNakitAkisi >=
                                          0
                                      ? Colors
                                          .deepPurple
                                      : Colors
                                          .red,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                                ),
                const SizedBox(height: 8),
                const Text(
                  'Net Kâr/Zarar; satışlardan hesaplanan brüt kârdan, '
                  'Gider / Masraf modülündeki iptal edilmemiş işletme giderleri '
                  'düşülerek hesaplanır. Dönem mal alışı ayrıca nakit akışı '
                  'karşılaştırması için gösterilir; stokta kalan mal doğrudan '
                  'net kârdan ikinci kez düşülmez.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _analizListeKarti({
    required String baslik,
    required IconData ikon,
    required List<String> satirlar,
  }) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            MobilYatayRow(
              children: [
                Icon(ikon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    baslik,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (satirlar.isEmpty)
              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  vertical: 20,
                ),
                child: Center(
                  child: Text(
                    'Veri yok',
                  ),
                ),
              )
            else
              ...satirlar
                  .asMap()
                  .entries
                  .map(
                (entry) {
                  final parcalar =
                      entry.value.split(
                    '|',
                  );

                  final ad =
                      parcalar.isEmpty
                          ? '-'
                          : parcalar.first;

                  final deger =
                      parcalar.length < 2
                          ? '-'
                          : parcalar
                              .sublist(1)
                              .join('|');

                  return Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 4,
                    ),
                    child: MobilYatayRow(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          child: Text(
                            '${entry.key + 1}',
                            style:
                                const TextStyle(
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: Text(
                            ad,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          deger,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'RAPORLAR VE ANALİZ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.trending_up), text: 'Satış'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Alış'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Stok'),
            Tab(icon: Icon(Icons.people), text: 'Cari'),
            Tab(
              icon: Icon(Icons.account_balance_wallet),
              text: 'Kasa',
            ),
            Tab(icon: Icon(Icons.bar_chart), text: 'Grafikler'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _satisRaporu(),
                _alisRaporu(),
                _stokRaporu(),
                _cariRaporu(),
                _kasaRaporu(),
                _grafikler(),
              ],
            ),
    );
  }
}