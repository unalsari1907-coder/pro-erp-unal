// lib/screens/kasa_banka_sayfasi.dart

import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import 'package:flutter/services.dart';

import '../services/supabase_service.dart';
import '../services/yetki_service.dart';

import 'finans_transfer_virman_sayfasi.dart';

class KasaBankaSayfasi extends StatefulWidget {
  final String gorunum;

  const KasaBankaSayfasi({super.key, this.gorunum = 'TUMU'});

  @override
  State<KasaBankaSayfasi> createState() => _KasaBankaSayfasiState();
}

class _KasaBankaSayfasiState extends State<KasaBankaSayfasi> {
  final TextEditingController _tutarController = TextEditingController();

  final TextEditingController _belgeNoController = TextEditingController();

  final TextEditingController _aciklamaController = TextEditingController();

  final TextEditingController _aramaController = TextEditingController();

  bool _yukleniyor = true;
  bool _kaydediliyor = false;

  int? _secilenCariId;
  int? _secilenKasaId;

  String _islemTipi = 'TAHSILAT';
  String _hareketFiltresi = 'TÜMÜ';

  DateTime _islemTarihi = DateTime.now();

  List<Map<String, dynamic>> _cariler = [];
  List<Map<String, dynamic>> _kasalar = [];
  List<Map<String, dynamic>> _tumHareketler = [];
  List<Map<String, dynamic>> _gorunenHareketler = [];

  @override
  void initState() {
    super.initState();

    _aramaController.addListener(_hareketleriFiltrele);

    _ilkVerileriYukle();
  }

  @override
  void dispose() {
    _tutarController.dispose();
    _belgeNoController.dispose();
    _aciklamaController.dispose();
    _aramaController.dispose();

    super.dispose();
  }

  Future<void> _ilkVerileriYukle() async {
    if (!mounted) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from('cariler')
            .select('cari_id, unvan, cari_tipi, bakiye, aktif')
            .eq('aktif', true)
            .order('unvan'),
        SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi, kasa_tipi')
            .order('kasa_adi'),
        SupabaseService.supabase
            .from('kasa_hareket')
            .select(
              'hareket_id, tarih, kasa_id, tip, tutar, '
              'aciklama, cari_id, kullanici, belge_no',
            )
            .order('tarih', ascending: false),
      ]);

      final cariler = List<Map<String, dynamic>>.from(sonuclar[0] as List);

      var kasalar = List<Map<String, dynamic>>.from(sonuclar[1] as List);

      final gorunum = widget.gorunum.toUpperCase();

      bool uygunKasa(Map<String, dynamic> kasa) {
        final ad = (kasa['kasa_adi']?.toString() ?? '').toUpperCase();
        final tip = (kasa['kasa_tipi']?.toString() ?? '').toUpperCase();

        if (gorunum == 'BANKA') {
          return tip.contains('BANKA') ||
              tip.contains('HESAP') ||
              ad.contains('BANKA') ||
              ad.contains('HESAP') ||
              ad.contains('ENPARA') ||
              ad.contains('GARANTI') ||
              ad.contains('GARANTİ') ||
              ad.contains('ZIRAAT') ||
              ad.contains('ZİRAAT');
        }

        if (gorunum == 'POS') {
          return tip.contains('POS') ||
              tip.contains('KART') ||
              ad.contains('POS') ||
              ad.contains('K.K') ||
              ad.contains('KREDI') ||
              ad.contains('KREDİ') ||
              ad.contains('KART');
        }

        return true;
      }

      kasalar = kasalar.where(uygunKasa).toList();

      final hareketler = List<Map<String, dynamic>>.from(sonuclar[2] as List);

      final cariHaritasi = <int, String>{};
      final kasaHaritasi = <int, String>{};

      for (final cari in cariler) {
        final cariId = int.tryParse(cari['cari_id']?.toString() ?? '');

        if (cariId != null) {
          cariHaritasi[cariId] = cari['unvan']?.toString() ?? '';
        }
      }

      for (final kasa in kasalar) {
        final kasaId = int.tryParse(kasa['kasa_id']?.toString() ?? '');

        if (kasaId != null) {
          kasaHaritasi[kasaId] = kasa['kasa_adi']?.toString() ?? '';
        }
      }

      for (final hareket in hareketler) {
        final cariId = int.tryParse(hareket['cari_id']?.toString() ?? '');

        final kasaId = int.tryParse(hareket['kasa_id']?.toString() ?? '');

        hareket['cari_unvan'] = cariId == null
            ? '-'
            : (cariHaritasi[cariId] ?? '-');

        hareket['kasa_adi'] = kasaId == null
            ? '-'
            : (kasaHaritasi[kasaId] ?? '-');
      }

      final izinliKasaIds = kasalar
          .map((e) => int.tryParse(e['kasa_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet();

      final filtreliHareketler = widget.gorunum.toUpperCase() == 'TUMU'
          ? hareketler
          : hareketler.where((h) {
              final id = int.tryParse(h['kasa_id']?.toString() ?? '');
              return id != null && izinliKasaIds.contains(id);
            }).toList();

      if (!mounted) return;

      setState(() {
        _cariler = cariler;
        _kasalar = kasalar;
        _tumHareketler = filtreliHareketler;
        _gorunenHareketler = filtreliHareketler;
        _yukleniyor = false;
      });

      if (_kasalar.isNotEmpty && _secilenKasaId == null) {
        _secilenKasaId = int.tryParse(_kasalar.first['kasa_id'].toString());
      }

      await _yeniBelgeNoGetir();
      _hareketleriFiltrele();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      _mesaj('Kasa verileri yüklenemedi: $e', Colors.red);
    }
  }

  Future<void> _yeniBelgeNoGetir() async {
    try {
      final response = await SupabaseService.supabase.rpc(
        'yeni_kasa_belge_no',
        params: {'p_islem_tipi': _islemTipi},
      );

      if (!mounted) return;

      _belgeNoController.text = response?.toString() ?? '';
    } catch (e) {
      if (!mounted) return;

      _belgeNoController.text = '';
      debugPrint('Kasa belge no üretilemedi: $e');
    }
  }

  void _hareketleriFiltrele() {
    final kelimeler = _aramaController.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((kelime) => kelime.isNotEmpty)
        .toList();

    if (!mounted) return;

    setState(() {
      _gorunenHareketler = _tumHareketler.where((hareket) {
        final tip = _metin(hareket['tip']).toUpperCase();

        if (_hareketFiltresi == 'GİRİŞ' &&
            !(tip == 'GIRIS' || tip == 'GİRİŞ')) {
          return false;
        }

        if (_hareketFiltresi == 'ÇIKIŞ' &&
            !(tip == 'CIKIS' || tip == 'ÇIKIŞ')) {
          return false;
        }

        if (kelimeler.isEmpty) {
          return true;
        }

        final aramaMetni = [
          hareket['belge_no'],
          hareket['cari_unvan'],
          hareket['kasa_adi'],
          hareket['tip'],
          hareket['aciklama'],
          hareket['kullanici'],
        ].map((deger) => deger?.toString() ?? '').join(' ').toLowerCase();

        return kelimeler.every(aramaMetni.contains);
      }).toList();
    });
  }

  Future<void> _islemTipiDegistir(String yeniTip) async {
    setState(() {
      _islemTipi = yeniTip;
      _secilenCariId = null;
      _tutarController.clear();
      _aciklamaController.clear();
    });

    await _yeniBelgeNoGetir();
  }

  Future<void> _tarihSec() async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: _islemTarihi,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (secilen == null) return;

    if (!mounted) return;

    setState(() {
      _islemTarihi = DateTime(
        secilen.year,
        secilen.month,
        secilen.day,
        DateTime.now().hour,
        DateTime.now().minute,
      );
    });
  }

  Future<void> _islemiKaydet() async {
    if (_kaydediliyor) return;

    final cariId = _secilenCariId;
    final kasaId = _secilenKasaId;

    final tutar =
        double.tryParse(_tutarController.text.trim().replaceAll(',', '.')) ??
        0.0;

    final belgeNo = _belgeNoController.text.trim();

    final aciklama = _aciklamaController.text.trim();

    if (cariId == null) {
      _mesaj('Cari seçmelisiniz.', Colors.red);
      return;
    }

    if (kasaId == null) {
      _mesaj('Kasa, banka, POS veya kredi kartı seçmelisiniz.', Colors.red);
      return;
    }

    if (tutar <= 0) {
      _mesaj('Tutar sıfırdan büyük olmalıdır.', Colors.red);
      return;
    }

    if (belgeNo.isEmpty) {
      _mesaj('Belge numarası boş bırakılamaz.', Colors.red);
      return;
    }

    final cari = _cariler.firstWhere(
      (item) => int.tryParse(item['cari_id'].toString()) == cariId,
    );

    final kasa = _kasalar.firstWhere(
      (item) => int.tryParse(item['kasa_id'].toString()) == kasaId,
    );

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _islemTipi == 'TAHSILAT' ? 'Tahsilatı Onayla' : 'Ödemeyi Onayla',
          ),
          content: Text(
            'Cari: ${_metin(cari['unvan'])}\n'
            'Kasa / Banka: ${_metin(kasa['kasa_adi'])}\n'
            'Belge No: $belgeNo\n'
            'Tutar: ${_para(tutar)}\n\n'
            'İşlem kaydedilsin mi?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (onay != true) return;

    setState(() {
      _kaydediliyor = true;
    });

    try {
      await SupabaseService.supabase.rpc(
        'kasa_cari_islemi_kaydet',
        params: {
          'p_islem_tipi': _islemTipi,
          'p_cari_id': cariId,
          'p_kasa_id': kasaId,
          'p_tutar': tutar,
          'p_belge_no': belgeNo,
          'p_aciklama': aciklama,
          'p_tarih': _islemTarihi.toUtc().toIso8601String(),
          'p_kullanici': YetkiService.aktifKullanici,
        },
      );

      if (!mounted) return;

      _mesaj(
        _islemTipi == 'TAHSILAT'
            ? 'Tahsilat başarıyla kaydedildi.'
            : 'Ödeme başarıyla kaydedildi.',
        Colors.green,
      );

      _tutarController.clear();
      _aciklamaController.clear();

      await _ilkVerileriYukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj('Kasa işlemi kaydedilemedi: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _kaydediliyor = false;
        });
      }
    }
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

  Map<String, dynamic>? _secilenCari() {
    if (_secilenCariId == null) return null;
    for (final cari in _cariler) {
      final id = int.tryParse(cari['cari_id']?.toString() ?? '');
      if (id == _secilenCariId) return cari;
    }
    return null;
  }

  Widget _secilenCariBakiyeKarti() {
    final cari = _secilenCari();
    if (cari == null) return const SizedBox.shrink();

    final bakiye = _sayi(cari['bakiye']);
    final tip = _metin(cari['cari_tipi']).toUpperCase();
    final tedarikci = tip.contains('TEDARIK') || tip.contains('TEDARİK');

    String durum;
    Color renk;
    if (bakiye == 0) {
      durum = 'HESAP KAPALI';
      renk = Colors.grey.shade700;
    } else {
      final alacakliyiz = tedarikci ? bakiye < 0 : bakiye > 0;
      durum = alacakliyiz ? 'ALACAKLIYIZ' : 'BORÇLUYUZ';
      renk = alacakliyiz ? Colors.green.shade700 : Colors.red.shade700;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: renk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cari Güncel Bakiye • $durum',
              style: TextStyle(fontWeight: FontWeight.w700, color: renk),
            ),
          ),
          Text(
            _para(bakiye.abs()),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: renk,
            ),
          ),
        ],
      ),
    );
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

  double _kasaBakiyesi(int kasaId) {
    double toplam = 0.0;

    for (final hareket in _tumHareketler) {
      final hareketKasaId = int.tryParse(hareket['kasa_id']?.toString() ?? '');

      if (hareketKasaId != kasaId) {
        continue;
      }

      final tutar = _sayi(hareket['tutar']);

      toplam += _girisMi(hareket) ? tutar : -tutar;
    }

    return toplam;
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  Future<void> _hesapFormuAc({Map<String, dynamic>? kasa}) async {
    final adController = TextEditingController(
      text: kasa?['kasa_adi']?.toString() ?? '',
    );
    const tipler = <String>['NAKIT', 'BANKA', 'POS', 'KREDI_KARTI'];
    final mevcutTip = kasa?['kasa_tipi']?.toString().toUpperCase() ?? '';
    var secilenTip = tipler.contains(mevcutTip)
        ? mevcutTip
        : widget.gorunum.toUpperCase() == 'BANKA'
        ? 'BANKA'
        : widget.gorunum.toUpperCase() == 'POS'
        ? 'POS'
        : 'NAKIT';

    Map<String, dynamic>? sonuc;

    try {
      sonuc = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  kasa == null ? 'Yeni Finans Hesabı' : 'Finans Hesabını Düzenle',
                ),
                content: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: adController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Hesap Adı',
                          prefixIcon: Icon(Icons.account_balance_wallet),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: secilenTip,
                        decoration: const InputDecoration(
                          labelText: 'Hesap Tipi',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'NAKIT', child: Text('Nakit Kasa')),
                          DropdownMenuItem(value: 'BANKA', child: Text('Banka Hesabı')),
                          DropdownMenuItem(value: 'POS', child: Text('POS')),
                          DropdownMenuItem(
                            value: 'KREDI_KARTI',
                            child: Text('Kredi Kartı'),
                          ),
                        ],
                        onChanged: (deger) {
                          if (deger == null) return;
                          setDialogState(() => secilenTip = deger);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Vazgeç'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final ad = adController.text.trim();
                      if (ad.isEmpty) {
                        _mesaj('Hesap adı boş bırakılamaz.', Colors.orange);
                        return;
                      }

                      Navigator.pop(dialogContext, <String, dynamic>{
                        'kasa_adi': ad,
                        'kasa_tipi': secilenTip,
                      });
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Kaydet'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      adController.dispose();
    }

    if (sonuc == null) return;

    try {
      if (kasa == null) {
        await SupabaseService.supabase.from('kasalar').insert(sonuc);
        _mesaj('Finans hesabı eklendi.', Colors.green);
      } else {
        final kasaId = int.tryParse(kasa['kasa_id']?.toString() ?? '');
        if (kasaId == null) return;

        await SupabaseService.supabase
            .from('kasalar')
            .update(sonuc)
            .eq('kasa_id', kasaId);
        _mesaj('Finans hesabı güncellendi.', Colors.green);
      }

      await _ilkVerileriYukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj('Finans hesabı kaydedilemedi: $e', Colors.red);
    }
  }

  Future<void> _hesapSil(Map<String, dynamic> kasa) async {
    final kasaId = int.tryParse(kasa['kasa_id']?.toString() ?? '');
    if (kasaId == null) return;

    try {
      final hareketler = await SupabaseService.supabase
          .from('kasa_hareket')
          .select('hareket_id')
          .eq('kasa_id', kasaId)
          .limit(1);

      if ((hareketler as List).isNotEmpty) {
        if (!mounted) return;
        _mesaj(
          'Bu hesapta finans hareketi bulunduğu için silinemez. '
          'Geçmiş kayıtların bozulmaması için hesabı düzenleyebilirsiniz.',
          Colors.orange,
        );
        return;
      }

      if (!mounted) return;
      final onay = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Finans Hesabını Sil'),
          content: Text(
            '${_metin(kasa['kasa_adi'])} hesabı kalıcı olarak silinsin mi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Sil'),
            ),
          ],
        ),
      );

      if (onay != true) return;

      await SupabaseService.supabase
          .from('kasalar')
          .delete()
          .eq('kasa_id', kasaId);

      if (_secilenKasaId == kasaId) _secilenKasaId = null;
      if (!mounted) return;
      _mesaj('Finans hesabı silindi.', Colors.green);
      await _ilkVerileriYukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj('Finans hesabı silinemedi: $e', Colors.red);
    }
  }

  Future<void> _hareketDetayGoster(Map<String, dynamic> hareket) async {
    final girisMi = _girisMi(hareket);
    final renk = girisMi ? Colors.green.shade700 : Colors.red.shade700;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: MobilYatayRow(
            children: [
              CircleAvatar(
                backgroundColor: renk.withOpacity(0.12),
                child: Icon(
                  girisMi ? Icons.south_west_rounded : Icons.north_east_rounded,
                  color: renk,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Kasa Hareket Detayı')),
            ],
          ),
          content: MobilDialogIcerik(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: renk.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: renk.withOpacity(0.22)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          girisMi ? 'GİRİŞ' : 'ÇIKIŞ',
                          style: TextStyle(
                            color: renk,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${girisMi ? '+' : '-'}${_para(hareket['tutar'])}',
                          style: TextStyle(
                            color: renk,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _hareketDetaySatiri(
                    'Hareket No',
                    _metin(hareket['hareket_id']),
                  ),
                  _hareketDetaySatiri(
                    'Kasa / Banka',
                    _metin(hareket['kasa_adi']),
                  ),
                  _hareketDetaySatiri('Cari', _metin(hareket['cari_unvan'])),
                  _hareketDetaySatiri('Belge No', _metin(hareket['belge_no'])),
                  _hareketDetaySatiri('Tarih', _tarih(hareket['tarih'])),
                  _hareketDetaySatiri(
                    'Hareket Tipi',
                    _metin(hareket['tip']),
                    renk: renk,
                    kalin: true,
                  ),
                  _hareketDetaySatiri('Açıklama', _metin(hareket['aciklama'])),
                  _hareketDetaySatiri(
                    'Kullanıcı',
                    _metin(hareket['kullanici']),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.close),
              label: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  Widget _hareketDetaySatiri(
    String baslik,
    String deger, {
    Color? renk,
    bool kalin = false,
  }) {
    final mobil = MobilUyum.telefon(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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

  Widget _islemFormu() {
    final tahsilatMi = _islemTipi == 'TAHSILAT';
    final mobil = MobilUyum.telefon(context);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'TAHSILAT',
                  icon: Icon(Icons.south_west),
                  label: Text('Tahsilat'),
                ),
                ButtonSegment<String>(
                  value: 'ODEME',
                  icon: Icon(Icons.north_east),
                  label: Text('Ödeme'),
                ),
              ],
              selected: {_islemTipi},
              onSelectionChanged: (secim) {
                _islemTipiDegistir(secim.first);
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: mobil ? double.infinity : 300,
                  child: DropdownButtonFormField<int>(
                    value: _secilenCariId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tahsilatMi
                          ? 'Tahsilat Yapılan Cari'
                          : 'Ödeme Yapılan Cari',
                      prefixIcon: const Icon(Icons.person),
                      border: const OutlineInputBorder(),
                    ),
                    items: _cariler.map((cari) {
                      return DropdownMenuItem<int>(
                        value: int.tryParse(cari['cari_id'].toString()),
                        child: Text(
                          _metin(cari['unvan']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (deger) {
                      setState(() {
                        _secilenCariId = deger;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: mobil ? double.infinity : 300,
                  child: DropdownButtonFormField<int>(
                    value: _secilenKasaId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tahsilatMi
                          ? 'Paranın Gireceği Kasa / Banka'
                          : 'Paranın Çıkacağı Kasa / Banka',
                      prefixIcon: const Icon(Icons.account_balance_wallet),
                      border: const OutlineInputBorder(),
                    ),
                    items: _kasalar.map((kasa) {
                      return DropdownMenuItem<int>(
                        value: int.tryParse(kasa['kasa_id'].toString()),
                        child: Text(
                          _metin(kasa['kasa_adi']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (deger) {
                      setState(() {
                        _secilenKasaId = deger;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: mobil ? double.infinity : 170,
                  child: TextField(
                    controller: _tutarController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Tutar',
                      prefixIcon: Icon(Icons.currency_lira),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: mobil ? double.infinity : 210,
                  child: TextField(
                    controller: _belgeNoController,
                    decoration: const InputDecoration(
                      labelText: 'Belge No',
                      prefixIcon: Icon(Icons.receipt_long),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _tarihSec,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_tarih(_islemTarihi)),
                ),
                SizedBox(
                  width: mobil ? double.infinity : 360,
                  child: TextField(
                    controller: _aciklamaController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: mobil ? double.infinity : null,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tahsilatMi ? Colors.green : Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _kaydediliyor ? null : _islemiKaydet,
                    icon: _kaydediliyor
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(tahsilatMi ? Icons.save : Icons.payment),
                    label: Text(
                      tahsilatMi ? 'Tahsilatı Kaydet' : 'Ödemeyi Kaydet',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _secilenCariBakiyeKarti(),
          ],
        ),
      ),
    );
  }

  String _gorunumBasligi() {
    final gorunum = widget.gorunum.toUpperCase();

    if (gorunum == 'BANKA') {
      return 'Banka Hesabı';
    }

    if (gorunum == 'POS') {
      return 'POS / Kredi Kartı';
    }

    return 'Kasa';
  }

  Future<void> _kasaDetayGoster(Map<String, dynamic> kasa) async {
    final kasaId = int.tryParse(kasa['kasa_id']?.toString() ?? '') ?? 0;

    final hareketler = _tumHareketler
        .where((h) => int.tryParse(h['kasa_id']?.toString() ?? '') == kasaId)
        .toList();

    double toplamGiris = 0;
    double toplamCikis = 0;

    for (final hareket in hareketler) {
      final tutar = _sayi(hareket['tutar']);

      if (_girisMi(hareket)) {
        toplamGiris += tutar;
      } else {
        toplamCikis += tutar;
      }
    }

    final bakiye = toplamGiris - toplamCikis;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: MobilDialogIcerik(
            width: 1100,
            height: 720,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  color: Colors.blueGrey.shade800,
                  child: MobilYatayRow(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _metin(kasa['kasa_adi']),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_gorunumBasligi()} Detayı',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: MobilYatayRow(
                    children: [
                      Expanded(
                        child: _detayOzetKarti(
                          'Güncel Bakiye',
                          _para(bakiye),
                          Icons.account_balance_wallet_outlined,
                          bakiye >= 0 ? Colors.blue : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detayOzetKarti(
                          'Toplam Giriş',
                          _para(toplamGiris),
                          Icons.south_west_rounded,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detayOzetKarti(
                          'Toplam Çıkış',
                          _para(toplamCikis),
                          Icons.north_east_rounded,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detayOzetKarti(
                          'Hareket Sayısı',
                          hareketler.length.toString(),
                          Icons.receipt_long_outlined,
                          Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: MobilYatayRow(
                    children: [
                      const Icon(Icons.history),
                      const SizedBox(width: 8),
                      const Text(
                        'HAREKETLER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${hareketler.length} kayıt',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: hareketler.isEmpty
                      ? const Center(
                          child: Text('Bu hesaba ait hareket bulunamadı.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          itemCount: hareketler.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 7),
                          itemBuilder: (context, index) {
                            final hareket = hareketler[index];

                            final girisMi = _girisMi(hareket);

                            final renk = girisMi ? Colors.green : Colors.red;

                            return Card(
                              elevation: 0.5,
                              child: ListTile(
                                onTap: () {
                                  _hareketDetayGoster(hareket);
                                },
                                leading: CircleAvatar(
                                  backgroundColor: renk.withOpacity(0.12),
                                  child: Icon(
                                    girisMi
                                        ? Icons.south_west_rounded
                                        : Icons.north_east_rounded,
                                    color: renk,
                                  ),
                                ),
                                title: Text(
                                  _metin(hareket['cari_unvan']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Belge: ${_metin(hareket['belge_no'])}'
                                  ' • ${_tarih(hareket['tarih'])}\n'
                                  '${_metin(hareket['aciklama'])}',
                                ),
                                isThreeLine: true,
                                trailing: SizedBox(
                                  width: 175,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${girisMi ? '+' : '-'}${_para(hareket['tutar'])}',
                                        style: TextStyle(
                                          color: renk,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _metin(hareket['tip']),
                                        style: TextStyle(
                                          color: renk,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: MobilYatayRow(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Kapat'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detayOzetKarti(
    String baslik,
    String deger,
    IconData ikon,
    Color renk,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: renk.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withOpacity(0.22)),
      ),
      child: MobilYatayRow(
        children: [
          CircleAvatar(
            backgroundColor: renk.withOpacity(0.12),
            child: Icon(ikon, color: renk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  deger,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _kasaKartlari() {
    if (_kasalar.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Kasa kaydı bulunamadı.'),
      );
    }

    return SizedBox(
      height: 135,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _kasalar.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final kasa = _kasalar[index];

          final kasaId = int.tryParse(kasa['kasa_id']?.toString() ?? '') ?? 0;

          final bakiye = _kasaBakiyesi(kasaId);

          return SizedBox(
            width: 290,
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _secilenKasaId = kasaId;
                  });

                  _kasaDetayGoster(kasa);
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MobilYatayRow(
                        children: [
                          Icon(
                            widget.gorunum.toUpperCase() == 'POS'
                                ? Icons.credit_card_rounded
                                : widget.gorunum.toUpperCase() == 'BANKA'
                                ? Icons.account_balance_rounded
                                : Icons.account_balance_wallet_rounded,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _metin(kasa['kasa_adi']),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Düzenle',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _hesapFormuAc(kasa: kasa),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Sil',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _hesapSil(kasa),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        _para(bakiye),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: bakiye >= 0 ? Colors.blue : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hareketListesi() {
    if (_gorunenHareketler.isEmpty) {
      return const Center(
        child: Text(
          'Kasa hareketi bulunamadı.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _gorunenHareketler.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final hareket = _gorunenHareketler[index];

        final girisMi = _girisMi(hareket);

        final renk = girisMi ? Colors.green : Colors.red;

        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () {
              _hareketDetayGoster(hareket);
            },
            leading: CircleAvatar(
              backgroundColor: renk.withOpacity(0.14),
              child: Icon(
                girisMi ? Icons.south_west : Icons.north_east,
                color: renk,
              ),
            ),
            title: Text(
              _metin(hareket['cari_unvan']),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Kasa: ${_metin(hareket['kasa_adi'])}\n'
              'Belge: ${_metin(hareket['belge_no'])} • '
              '${_tarih(hareket['tarih'])}\n'
              '${_metin(hareket['aciklama'])}',
            ),
            trailing: SizedBox(
              width: 150,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${girisMi ? '+' : '-'}'
                    '${_para(hareket['tutar'])}',
                    style: TextStyle(
                      color: renk,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _metin(hareket['tip']),
                    style: TextStyle(
                      color: renk,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          widget.gorunum.toUpperCase() == 'BANKA'
              ? 'BANKALAR'
              : widget.gorunum.toUpperCase() == 'POS'
              ? 'POS / KREDİ KARTLARI'
              : 'KASA / BANKA / POS',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          MobilAppBarActions(
            children: [
              ElevatedButton.icon(
                onPressed: () => _hesapFormuAc(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Yeni Hesap'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const FinansTransferVirmanSayfasi(),
                    ),
                  );

                  if (!mounted) return;

                  await _ilkVerileriYukle();
                },
                icon: const Icon(Icons.compare_arrows_rounded),
                label: const Text('Transfer / Virman'),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Yenile',
                onPressed: _ilkVerileriYukle,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _islemFormu(),
                _kasaKartlari(),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: MobilYatayRow(
                    minWidth: 760,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _aramaController,
                          decoration: InputDecoration(
                            hintText: 'Cari, kasa, belge no, açıklama...',
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
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 170,
                        child: DropdownButtonFormField<String>(
                          value: _hareketFiltresi,
                          decoration: const InputDecoration(
                            labelText: 'Hareket',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'TÜMÜ',
                              child: Text('Tüm Hareketler'),
                            ),
                            DropdownMenuItem(
                              value: 'GİRİŞ',
                              child: Text('Para Girişleri'),
                            ),
                            DropdownMenuItem(
                              value: 'ÇIKIŞ',
                              child: Text('Para Çıkışları'),
                            ),
                          ],
                          onChanged: (deger) {
                            if (deger == null) {
                              return;
                            }

                            setState(() {
                              _hareketFiltresi = deger;
                            });

                            _hareketleriFiltrele();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _hareketListesi()),
              ],
            ),
    );
  }
}
