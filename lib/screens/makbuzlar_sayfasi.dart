// lib/screens/makbuzlar_sayfasi.dart

import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import '../services/supabase_service.dart';
import '../services/kurumsal_yazdirma_service.dart';
import '../services/yetki_service.dart';

class MakbuzlarSayfasi extends StatefulWidget {
  const MakbuzlarSayfasi({super.key});

  @override
  State<MakbuzlarSayfasi> createState() => _MakbuzlarSayfasiState();
}

class _MakbuzlarSayfasiState extends State<MakbuzlarSayfasi> {
  final TextEditingController _aramaController = TextEditingController();

  bool _yukleniyor = true;
  bool _islemYapiliyor = false;

  String _aktifTur = 'TAHSILAT';
  String _durumFiltresi = 'TÜMÜ';

  List<Map<String, dynamic>> _tumMakbuzlar = [];
  List<Map<String, dynamic>> _gorunenMakbuzlar = [];

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
            .from('kasa_hareket')
            .select(
              'hareket_id, tarih, kasa_id, tip, tutar, belge_no, '
              'aciklama, cari_id, kullanici',
            )
            .order('tarih', ascending: false),
        SupabaseService.supabase
            .from('cari_hareket')
            .select(
              'hareket_id, tarih, cari_id, islem_tipi, belge_no, '
              'borc, alacak, aciklama, kullanici',
            )
            .order('tarih', ascending: false),
        SupabaseService.supabase
            .from('cariler')
            .select(
              'cari_id, unvan, cari_tipi, bakiye',
            ),
        SupabaseService.supabase
            .from('kasalar')
            .select(
              'kasa_id, kasa_adi, kasa_tipi',
            ),
      ]);

      final kasaHareketleri =
          List<Map<String, dynamic>>.from(sonuclar[0] as List);

      final cariHareketleri =
          List<Map<String, dynamic>>.from(sonuclar[1] as List);

      final cariler =
          List<Map<String, dynamic>>.from(sonuclar[2] as List);

      final kasalar =
          List<Map<String, dynamic>>.from(sonuclar[3] as List);

      final cariHaritasi = <int, Map<String, dynamic>>{};
      final kasaHaritasi = <int, Map<String, dynamic>>{};

      for (final cari in cariler) {
        final cariId = int.tryParse(
          cari['cari_id']?.toString() ?? '',
        );

        if (cariId != null) {
          cariHaritasi[cariId] = cari;
        }
      }

      for (final kasa in kasalar) {
        final kasaId = int.tryParse(
          kasa['kasa_id']?.toString() ?? '',
        );

        if (kasaId != null) {
          kasaHaritasi[kasaId] = kasa;
        }
      }

      final cariHareketHaritasi =
          <String, Map<String, dynamic>>{};

      for (final hareket in cariHareketleri) {
        final belgeNo =
            hareket['belge_no']?.toString().trim() ?? '';

        final cariId =
            hareket['cari_id']?.toString() ?? '';

        if (belgeNo.isEmpty || cariId.isEmpty) continue;

        final anahtar = '${belgeNo.toUpperCase()}|$cariId';

        cariHareketHaritasi.putIfAbsent(
          anahtar,
          () => hareket,
        );
      }

      final makbuzlar = <Map<String, dynamic>>[];

      for (final hareket in kasaHareketleri) {
        final belgeNo =
            hareket['belge_no']?.toString().trim() ?? '';

        final cariId = int.tryParse(
          hareket['cari_id']?.toString() ?? '',
        );

        final kasaId = int.tryParse(
          hareket['kasa_id']?.toString() ?? '',
        );

        if (cariId == null || belgeNo.isEmpty) continue;

        final anahtar = '${belgeNo.toUpperCase()}|$cariId';
        final cariHareket = cariHareketHaritasi[anahtar];

        final islemTipi = _islemTipiBelirle(
          kasaHareket: hareket,
          cariHareket: cariHareket,
        );

        if (islemTipi != 'TAHSILAT' && islemTipi != 'ODEME') {
          continue;
        }

        final cari = cariHaritasi[cariId];
        final kasa = kasaId == null ? null : kasaHaritasi[kasaId];

        final kayit = Map<String, dynamic>.from(hareket);

        kayit['makbuz_turu'] = islemTipi;
        kayit['cari_unvan'] =
            cari?['unvan']?.toString() ?? '-';
        kayit['cari_tipi'] =
            cari?['cari_tipi']?.toString() ?? '-';
        kayit['cari_bakiye'] =
            cari?['bakiye'] ?? 0;
        kayit['kasa_adi'] =
            kasa?['kasa_adi']?.toString() ?? '-';
        kayit['kasa_tipi'] =
            kasa?['kasa_tipi']?.toString() ?? '-';
        kayit['cari_hareket_id'] =
            cariHareket?['hareket_id'];
        kayit['cari_islem_tipi'] =
            cariHareket?['islem_tipi'];

        final aciklama =
            kayit['aciklama']?.toString().toUpperCase() ?? '';

        kayit['iptal_mi'] =
            aciklama.contains('IPTAL EDILDI') ||
            aciklama.contains('İPTAL EDİLDİ');

        makbuzlar.add(kayit);
      }

      if (!mounted) return;

      setState(() {
        _tumMakbuzlar = makbuzlar;
        _gorunenMakbuzlar = makbuzlar;
        _yukleniyor = false;
      });

      _filtrele();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      _mesaj(
        'Makbuzlar yüklenemedi: $e',
        Colors.red,
      );
    }
  }

  String _islemTipiBelirle({
    required Map<String, dynamic> kasaHareket,
    Map<String, dynamic>? cariHareket,
  }) {
    final cariIslem =
        cariHareket?['islem_tipi']?.toString().toUpperCase() ?? '';

    if (cariIslem.contains('TAHSILAT') ||
        cariIslem.contains('TAHSİLAT')) {
      return 'TAHSILAT';
    }

    if (cariIslem.contains('ODEME') ||
        cariIslem.contains('ÖDEME')) {
      return 'ODEME';
    }

    final tip =
        kasaHareket['tip']?.toString().toUpperCase() ?? '';

    final belgeNo =
        kasaHareket['belge_no']?.toString().toUpperCase() ?? '';

    if (belgeNo.startsWith('TH-')) return 'TAHSILAT';
    if (belgeNo.startsWith('OD-')) return 'ODEME';

    if (tip == 'GIRIS' || tip == 'GİRİŞ') return 'TAHSILAT';
    if (tip == 'CIKIS' || tip == 'ÇIKIŞ') return 'ODEME';

    return '';
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
      _gorunenMakbuzlar = _tumMakbuzlar.where((makbuz) {
        if (makbuz['makbuz_turu'] != _aktifTur) {
          return false;
        }

        final iptalMi = makbuz['iptal_mi'] == true;

        if (_durumFiltresi == 'AKTİF' && iptalMi) {
          return false;
        }

        if (_durumFiltresi == 'İPTAL' && !iptalMi) {
          return false;
        }

        if (kelimeler.isEmpty) return true;

        final metin = [
          makbuz['belge_no'],
          makbuz['cari_unvan'],
          makbuz['cari_tipi'],
          makbuz['kasa_adi'],
          makbuz['kasa_tipi'],
          makbuz['aciklama'],
          makbuz['kullanici'],
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

  String _odemeTuru(Map<String, dynamic> makbuz) {
    final kasaTipi =
        _metin(makbuz['kasa_tipi']).toUpperCase();

    final kasaAdi =
        _metin(makbuz['kasa_adi']).toUpperCase();

    if (kasaTipi.contains('POS') || kasaAdi.contains('POS')) {
      return 'POS';
    }

    if (kasaTipi.contains('KREDI') ||
        kasaTipi.contains('KREDİ') ||
        kasaAdi.contains('K.K')) {
      return 'Kredi Kartı';
    }

    if (kasaTipi.contains('BANKA') ||
        kasaAdi.contains('BANKA') ||
        kasaAdi.contains('HESAP')) {
      return 'Havale / Banka';
    }

    return 'Nakit';
  }

  Color _turRengi(Map<String, dynamic> makbuz) {
    if (makbuz['iptal_mi'] == true) {
      return Colors.grey.shade700;
    }

    return makbuz['makbuz_turu'] == 'TAHSILAT'
        ? Colors.green.shade700
        : Colors.red.shade700;
  }

  IconData _turIkonu(Map<String, dynamic> makbuz) {
    if (makbuz['iptal_mi'] == true) {
      return Icons.cancel;
    }

    return makbuz['makbuz_turu'] == 'TAHSILAT'
        ? Icons.south_west
        : Icons.north_east;
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: renk,
      ),
    );
  }

  Future<void> _makbuzIptalEt(
    Map<String, dynamic> makbuz,
  ) async {
    if (_islemYapiliyor) return;

    if (makbuz['iptal_mi'] == true) {
      _mesaj(
        'Bu makbuz daha önce iptal edilmiş.',
        Colors.orange,
      );
      return;
    }

    final hareketId = int.tryParse(
      makbuz['hareket_id']?.toString() ?? '',
    );

    if (hareketId == null) {
      _mesaj(
        'Geçersiz kasa hareketi.',
        Colors.red,
      );
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Makbuzu İptal Et'),
          content: Text(
            'Belge No: ${_metin(makbuz['belge_no'])}\n'
            'Cari: ${_metin(makbuz['cari_unvan'])}\n'
            'Kasa: ${_metin(makbuz['kasa_adi'])}\n'
            'Tutar: ${_para(makbuz['tutar'])}\n\n'
            'Makbuz ters kayıt oluşturularak iptal edilecek. '
            'Devam edilsin mi?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Vazgeç'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.cancel),
              label: const Text('İptal Et'),
            ),
          ],
        );
      },
    );

    if (onay != true) return;

    setState(() {
      _islemYapiliyor = true;
    });

    try {
      await SupabaseService.supabase.rpc(
        'kasa_makbuzu_iptal_et',
        params: {
          'p_hareket_id': hareketId,
          'p_kullanici': YetkiService.aktifKullanici,
        },
      );

      if (!mounted) return;

      _mesaj(
        'Makbuz başarıyla iptal edildi.',
        Colors.green,
      );

      await _verileriYukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj(
        'Makbuz iptal hatası: $e',
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

  void _detayGoster(Map<String, dynamic> makbuz) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final renk = _turRengi(makbuz);
        final aktifMi = makbuz['iptal_mi'] != true;

        return AlertDialog(
          title: MobilYatayRow(
            children: [
              Icon(
                _turIkonu(makbuz),
                color: renk,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  makbuz['makbuz_turu'] == 'TAHSILAT'
                      ? 'Tahsilat Makbuzu'
                      : 'Ödeme Makbuzu',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: renk.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: MobilYatayRow(
                  children: [
                    Icon(
                      aktifMi
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: renk,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      aktifMi ? 'AKTİF' : 'İPTAL',
                      style: TextStyle(
                        color: renk,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: MobilDialogIcerik(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detaySatiri(
                    'Belge No',
                    _metin(makbuz['belge_no']),
                  ),
                  _detaySatiri(
                    'Tarih / Saat',
                    _tarih(makbuz['tarih']),
                  ),
                  _detaySatiri(
                    'Cari',
                    _metin(makbuz['cari_unvan']),
                  ),
                  _detaySatiri(
                    'Cari Tipi',
                    _metin(makbuz['cari_tipi']),
                  ),
                  _detaySatiri(
                    'Ödeme Türü',
                    _odemeTuru(makbuz),
                  ),
                  _detaySatiri(
                    'Kasa / Banka / POS',
                    _metin(makbuz['kasa_adi']),
                  ),
                  _detaySatiri(
                    'Tutar',
                    _para(makbuz['tutar']),
                    renk: renk,
                    kalin: true,
                  ),
                  _detaySatiri(
                    'Cari Güncel Bakiye',
                    _para(makbuz['cari_bakiye']),
                    renk: Colors.blue.shade700,
                    kalin: true,
                  ),
                  const Divider(height: 24),
                  _detaySatiri(
                    'Açıklama / Not',
                    _metin(makbuz['aciklama']),
                  ),
                  _detaySatiri(
                    'Oluşturan Kullanıcı',
                    _metin(makbuz['kullanici']),
                  ),
                  const Divider(height: 24),
                  _detaySatiri(
                    'Kasa Hareket ID',
                    _metin(makbuz['hareket_id']),
                  ),
                  _detaySatiri(
                    'Cari Hareket ID',
                    _metin(makbuz['cari_hareket_id']),
                  ),
                  _detaySatiri(
                    'Cari İşlem Tipi',
                    _metin(makbuz['cari_islem_tipi']),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (aktifMi)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _makbuzIptalEt(makbuz);
                },
                icon: const Icon(Icons.cancel),
                label: const Text('Makbuzu İptal Et'),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await KurumsalYazdirmaService.makbuzYazdir(makbuz);
                } catch (e) {
                  if (mounted) {
                    _mesaj('Makbuz yazdırılamadı: $e', Colors.red);
                  }
                }
              },
              icon: const Icon(Icons.print),
              label: const Text('Yazdır'),
            ),
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
      child: MobilYatayRow(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              baslik,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              deger,
              style: TextStyle(
                color: renk,
                fontWeight:
                    kalin ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _makbuzKarti(Map<String, dynamic> makbuz) {
    final renk = _turRengi(makbuz);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _detayGoster(makbuz);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: MobilYatayRow(
            children: [
              CircleAvatar(
                backgroundColor: renk.withOpacity(0.14),
                child: Icon(
                  _turIkonu(makbuz),
                  color: renk,
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metin(makbuz['belge_no']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tarih(makbuz['tarih']),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metin(makbuz['cari_unvan']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 18,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Tür: ${_odemeTuru(makbuz)}',
                        ),
                        Text(
                          'Kasa: ${_metin(makbuz['kasa_adi'])}',
                        ),
                        Text(
                          'Kullanıcı: ${_metin(makbuz['kullanici'])}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Not: ${_metin(makbuz['aciklama'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 170,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _para(makbuz['tutar']),
                      style: TextStyle(
                        color: renk,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      makbuz['iptal_mi'] == true
                          ? 'İPTAL'
                          : 'AKTİF',
                      style: TextStyle(
                        color: renk,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'İşlemler',
                onSelected: (deger) {
                  if (deger == 'detay') {
                    _detayGoster(makbuz);
                  } else if (deger == 'iptal') {
                    _makbuzIptalEt(makbuz);
                  }
                },
                itemBuilder: (context) {
                  return [
                    const PopupMenuItem<String>(
                      value: 'detay',
                      child: ListTile(
                        leading: Icon(Icons.visibility),
                        title: Text('Görüntüle'),
                      ),
                    ),
                    if (makbuz['iptal_mi'] != true)
                      const PopupMenuItem<String>(
                        value: 'iptal',
                        child: ListTile(
                          leading: Icon(
                            Icons.cancel,
                            color: Colors.red,
                          ),
                          title: Text(
                            'Makbuzu İptal Et',
                            style: TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _toplamTutar {
    return _gorunenMakbuzlar
        .where(
          (makbuz) => makbuz['iptal_mi'] != true,
        )
        .fold<double>(
          0,
          (toplam, makbuz) =>
              toplam + _sayi(makbuz['tutar']),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'TAHSİLAT / ÖDEME MAKBUZLARI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
            child: Column(
              children: [
                MobilYatayRow(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'TAHSILAT',
                            icon: Icon(Icons.south_west),
                            label: Text(
                              'Tahsilat Makbuzları',
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'ODEME',
                            icon: Icon(Icons.north_east),
                            label: Text(
                              'Ödeme Makbuzları',
                            ),
                          ),
                        ],
                        selected: {_aktifTur},
                        onSelectionChanged: (secim) {
                          setState(() {
                            _aktifTur = secim.first;
                          });

                          _filtrele();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 230,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _aktifTur == 'TAHSILAT'
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Aktif Makbuz Toplamı',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _para(_toplamTutar),
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: _aktifTur == 'TAHSILAT'
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                MobilYatayRow(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aramaController,
                        decoration: InputDecoration(
                          hintText:
                              'Belge no, cari, kasa, ödeme türü, açıklama, kullanıcı...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _aramaController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed:
                                          _aramaController.clear,
                                      icon:
                                          const Icon(Icons.clear),
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
                      width: 165,
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
                            value: 'AKTİF',
                            child: Text('Aktif'),
                          ),
                          DropdownMenuItem(
                            value: 'İPTAL',
                            child: Text('İptal'),
                          ),
                        ],
                        onChanged: (deger) {
                          if (deger == null) return;

                          setState(() {
                            _durumFiltresi = deger;
                          });

                          _filtrele();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _gorunenMakbuzlar.isEmpty
                    ? const Center(
                        child: Text(
                          'Makbuz bulunamadı.',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _verileriYukle,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount:
                              _gorunenMakbuzlar.length,
                          separatorBuilder: (_, __) {
                            return const SizedBox(height: 8);
                          },
                          itemBuilder: (context, index) {
                            return _makbuzKarti(
                              _gorunenMakbuzlar[index],
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
