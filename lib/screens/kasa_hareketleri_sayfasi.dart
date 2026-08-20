// lib/screens/kasa_hareketleri_sayfasi.dart

import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import '../services/supabase_service.dart';

class KasaHareketleriSayfasi extends StatefulWidget {
  const KasaHareketleriSayfasi({super.key});

  @override
  State<KasaHareketleriSayfasi> createState() => _KasaHareketleriSayfasiState();
}

class _KasaHareketleriSayfasiState extends State<KasaHareketleriSayfasi> {
  final TextEditingController _aramaController = TextEditingController();

  bool _yukleniyor = true;

  int? _secilenKasaId;
  String _tipFiltresi = 'TÜMÜ';

  DateTime? _baslangicTarihi;
  DateTime? _bitisTarihi;

  List<Map<String, dynamic>> _kasalar = [];
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
            .from('kasa_hareket')
            .select(
              'hareket_id, tarih, kasa_id, tip, tutar, '
              'aciklama, cari_id, kullanici',
            )
            .order('tarih', ascending: false),
        SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi')
            .order('kasa_adi'),
        SupabaseService.supabase.from('cariler').select('cari_id, unvan'),
      ]);

      final hareketler = List<Map<String, dynamic>>.from(sonuclar[0] as List);

      final kasalar = List<Map<String, dynamic>>.from(sonuclar[1] as List);

      final cariler = List<Map<String, dynamic>>.from(sonuclar[2] as List);

      final kasaHaritasi = <int, String>{};
      final cariHaritasi = <int, String>{};

      for (final kasa in kasalar) {
        final kasaId = int.tryParse(kasa['kasa_id']?.toString() ?? '');

        if (kasaId != null) {
          kasaHaritasi[kasaId] = kasa['kasa_adi']?.toString() ?? '';
        }
      }

      for (final cari in cariler) {
        final cariId = int.tryParse(cari['cari_id']?.toString() ?? '');

        if (cariId != null) {
          cariHaritasi[cariId] = cari['unvan']?.toString() ?? '';
        }
      }

      for (final hareket in hareketler) {
        final kasaId = int.tryParse(hareket['kasa_id']?.toString() ?? '');

        final cariId = int.tryParse(hareket['cari_id']?.toString() ?? '');

        hareket['kasa_adi'] = kasaId == null
            ? '-'
            : (kasaHaritasi[kasaId] ?? '-');

        hareket['cari_unvan'] = cariId == null
            ? '-'
            : (cariHaritasi[cariId] ?? '-');
      }

      if (!mounted) return;

      setState(() {
        _kasalar = kasalar;
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

      _mesaj('Kasa hareketleri yüklenemedi: $e', Colors.red);
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
        final kasaId = int.tryParse(hareket['kasa_id']?.toString() ?? '');

        if (_secilenKasaId != null && kasaId != _secilenKasaId) {
          return false;
        }

        final tip = _metin(hareket['tip']).toUpperCase();

        if (_tipFiltresi != 'TÜMÜ') {
          final girisMi = tip == 'GIRIS' || tip == 'GİRİŞ';

          final cikisMi = tip == 'CIKIS' || tip == 'ÇIKIŞ';

          if (_tipFiltresi == 'GİRİŞ' && !girisMi) {
            return false;
          }

          if (_tipFiltresi == 'ÇIKIŞ' && !cikisMi) {
            return false;
          }
        }

        final tarih = DateTime.tryParse(hareket['tarih']?.toString() ?? '')
            ?.toLocal();

        if (_baslangicTarihi != null &&
            tarih != null &&
            tarih.isBefore(
              DateTime(
                _baslangicTarihi!.year,
                _baslangicTarihi!.month,
                _baslangicTarihi!.day,
              ),
            )) {
          return false;
        }

        if (_bitisTarihi != null && tarih != null) {
          final bitisSonu = DateTime(
            _bitisTarihi!.year,
            _bitisTarihi!.month,
            _bitisTarihi!.day,
            23,
            59,
            59,
          );

          if (tarih.isAfter(bitisSonu)) {
            return false;
          }
        }

        if (kelimeler.isEmpty) return true;

        final metin = [
          hareket['hareket_id'],
          hareket['kasa_adi'],
          hareket['tip'],
          hareket['cari_unvan'],
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
    final tip = _metin(hareket['tip']).toUpperCase();

    return tip == 'GIRIS' || tip == 'GİRİŞ';
  }

  Color _hareketRengi(Map<String, dynamic> hareket) {
    return _girisMi(hareket) ? Colors.green.shade700 : Colors.red.shade700;
  }

  IconData _hareketIkonu(Map<String, dynamic> hareket) {
    return _girisMi(hareket) ? Icons.south_west : Icons.north_east;
  }

  double get _toplamGiris {
    return _gorunenHareketler
        .where(_girisMi)
        .fold<double>(0, (toplam, hareket) => toplam + _sayi(hareket['tutar']));
  }

  double get _toplamCikis {
    return _gorunenHareketler
        .where((hareket) => !_girisMi(hareket))
        .fold<double>(0, (toplam, hareket) => toplam + _sayi(hareket['tutar']));
  }

  double get _netBakiye {
    return _toplamGiris - _toplamCikis;
  }

  Future<void> _tarihSec({required bool baslangic}) async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: baslangic
          ? (_baslangicTarihi ?? DateTime.now())
          : (_bitisTarihi ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (secilen == null) return;

    setState(() {
      if (baslangic) {
        _baslangicTarihi = secilen;
      } else {
        _bitisTarihi = secilen;
      }
    });

    _filtrele();
  }

  void _filtreleriTemizle() {
    setState(() {
      _aramaController.clear();
      _secilenKasaId = null;
      _tipFiltresi = 'TÜMÜ';
      _baslangicTarihi = null;
      _bitisTarihi = null;
    });

    _filtrele();
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
          title: MobilYatayRow(
            children: [
              Icon(_hareketIkonu(hareket), color: _hareketRengi(hareket)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Kasa Hareket Detayı')),
            ],
          ),
          content: MobilDialogIcerik(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detaySatiri('Kasa', _metin(hareket['kasa_adi'])),
                  _detaySatiri('Hareket No', _metin(hareket['hareket_id'])),
                  _detaySatiri(
                    'Hareket Tipi',
                    _metin(hareket['tip']),
                    renk: _hareketRengi(hareket),
                    kalin: true,
                  ),
                  _detaySatiri(
                    'Tutar',
                    _para(hareket['tutar']),
                    renk: _hareketRengi(hareket),
                    kalin: true,
                  ),
                  const Divider(height: 24),
                  _detaySatiri('Cari', _metin(hareket['cari_unvan'])),
                  _detaySatiri('Belge No', _metin(hareket['belge_no'])),
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
                  width: 145,
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

  Widget _ozetKarti({
    required String baslik,
    required String deger,
    required IconData ikon,
    required Color renk,
  }) {
    final kart = Card(
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
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
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
    );

    if (MobilUyum.telefon(context)) {
      return SizedBox(width: double.infinity, child: kart);
    }

    return Expanded(child: kart);
  }

  Widget _hareketKarti(Map<String, dynamic> hareket) {
    final renk = _hareketRengi(hareket);

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
                child: Icon(_hareketIkonu(hareket), color: renk),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metin(hareket['kasa_adi']),
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
                        Text('Cari: ${_metin(hareket['cari_unvan'])}'),
                        Text('Kullanıcı: ${_metin(hareket['kullanici'])}'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metin(hareket['tip']),
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
                width: 165,
                child: Text(
                  _para(hareket['tutar']),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: renk,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
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
                    child: Icon(_hareketIkonu(hareket), color: renk),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _metin(hareket['kasa_adi']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _metin(hareket['tip']),
                          style: TextStyle(
                            color: renk,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _para(hareket['tutar']),
                    style: TextStyle(
                      color: renk,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                'Cari: ${_metin(hareket['cari_unvan'])}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
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
          'KASA HAREKETLERİ',
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
              children: [
                SizedBox(
                  width: mobil ? double.infinity : 330,
                  child: TextField(
                    controller: _aramaController,
                    decoration: InputDecoration(
                      hintText: 'Kasa, cari, açıklama, kullanıcı...',
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
                SizedBox(
                  width: mobil ? double.infinity : 240,
                  child: DropdownButtonFormField<int?>(
                    value: _secilenKasaId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kasa / Banka',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tüm Kasalar'),
                      ),
                      ..._kasalar.map((kasa) {
                        return DropdownMenuItem<int?>(
                          value: int.tryParse(kasa['kasa_id'].toString()),
                          child: Text(
                            kasa['kasa_adi']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (deger) {
                      setState(() {
                        _secilenKasaId = deger;
                      });

                      _filtrele();
                    },
                  ),
                ),
                SizedBox(
                  width: mobil ? double.infinity : 160,
                  child: DropdownButtonFormField<String>(
                    value: _tipFiltresi,
                    decoration: const InputDecoration(
                      labelText: 'Hareket Tipi',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'TÜMÜ',
                        child: Text('Tüm Hareketler'),
                      ),
                      DropdownMenuItem(value: 'GİRİŞ', child: Text('Giriş')),
                      DropdownMenuItem(value: 'ÇIKIŞ', child: Text('Çıkış')),
                    ],
                    onChanged: (deger) {
                      if (deger == null) return;

                      setState(() {
                        _tipFiltresi = deger;
                      });

                      _filtrele();
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _tarihSec(baslangic: true);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _baslangicTarihi == null
                        ? 'Başlangıç'
                        : _tarih(_baslangicTarihi),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _tarihSec(baslangic: false);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    _bitisTarihi == null ? 'Bitiş' : _tarih(_bitisTarihi),
                  ),
                ),
                TextButton.icon(
                  onPressed: _filtreleriTemizle,
                  icon: const Icon(Icons.clear),
                  label: const Text('Temizle'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: mobil
                ? Column(
                    children: [
                      _ozetKarti(
                        baslik: 'Toplam Giriş',
                        deger: _para(_toplamGiris),
                        ikon: Icons.south_west,
                        renk: Colors.green.shade700,
                      ),
                      _ozetKarti(
                        baslik: 'Toplam Çıkış',
                        deger: _para(_toplamCikis),
                        ikon: Icons.north_east,
                        renk: Colors.red.shade700,
                      ),
                      _ozetKarti(
                        baslik: 'Net Bakiye',
                        deger: _para(_netBakiye),
                        ikon: Icons.account_balance_wallet,
                        renk: _netBakiye >= 0
                            ? Colors.blue.shade700
                            : Colors.orange.shade800,
                      ),
                    ],
                  )
                : MobilYatayRow(
                    minWidth: 760,
                    children: [
                      _ozetKarti(
                        baslik: 'Toplam Giriş',
                        deger: _para(_toplamGiris),
                        ikon: Icons.south_west,
                        renk: Colors.green.shade700,
                      ),
                      const SizedBox(width: 10),
                      _ozetKarti(
                        baslik: 'Toplam Çıkış',
                        deger: _para(_toplamCikis),
                        ikon: Icons.north_east,
                        renk: Colors.red.shade700,
                      ),
                      const SizedBox(width: 10),
                      _ozetKarti(
                        baslik: 'Net Bakiye',
                        deger: _para(_netBakiye),
                        ikon: Icons.account_balance_wallet,
                        renk: _netBakiye >= 0
                            ? Colors.blue.shade700
                            : Colors.orange.shade800,
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
                      'Kasa hareketi bulunamadı.',
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
