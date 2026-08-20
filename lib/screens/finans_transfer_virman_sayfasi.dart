import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import 'package:flutter/services.dart';

import '../services/supabase_service.dart';
import '../services/yetki_service.dart';

class FinansTransferVirmanSayfasi extends StatefulWidget {
  const FinansTransferVirmanSayfasi({super.key});

  @override
  State<FinansTransferVirmanSayfasi> createState() =>
      _FinansTransferVirmanSayfasiState();
}

class _FinansTransferVirmanSayfasiState
    extends State<FinansTransferVirmanSayfasi>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final TextEditingController _transferTutar = TextEditingController();
  final TextEditingController _transferAciklama = TextEditingController();

  final TextEditingController _virmanTutar = TextEditingController();
  final TextEditingController _virmanAciklama = TextEditingController();

  bool _yukleniyor = true;
  bool _kaydediliyor = false;

  DateTime _transferTarih = DateTime.now();
  DateTime _virmanTarih = DateTime.now();

  int? _kaynakKasaId;
  int? _hedefKasaId;
  int? _musteriCariId;
  int? _tedarikciCariId;

  List<Map<String, dynamic>> _kasalar = [];
  final Map<int, double> _kasaBakiyeleri = {};
  List<Map<String, dynamic>> _cariler = [];
  List<Map<String, dynamic>> _transferler = [];
  List<Map<String, dynamic>> _virmanlar = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _verileriYukle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transferTutar.dispose();
    _transferAciklama.dispose();
    _virmanTutar.dispose();
    _virmanAciklama.dispose();

    super.dispose();
  }

  String _metin(dynamic deger) {
    final sonuc = deger?.toString().trim() ?? '';

    return sonuc.isEmpty ? '-' : sonuc;
  }

  double _sayi(dynamic deger) {
    if (deger is num) {
      return deger.toDouble();
    }

    return double.tryParse(deger?.toString().replaceAll(',', '.') ?? '0') ?? 0;
  }

  String _para(dynamic deger) {
    return '${_sayi(deger).toStringAsFixed(2)} ₺';
  }

  String _tarih(dynamic deger) {
    final tarih = DateTime.tryParse(deger?.toString() ?? '')?.toLocal();

    if (tarih == null) return '-';

    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year} '
        '${tarih.hour.toString().padLeft(2, '0')}:'
        '${tarih.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _verileriYukle() async {
    if (!mounted) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi, kasa_tipi')
            .order('kasa_adi'),
        SupabaseService.supabase
            .from('kasa_hareket')
            .select('kasa_id, tip, tutar'),
        SupabaseService.supabase
            .from('cariler')
            .select('cari_id, unvan, cari_tipi, bakiye, aktif')
            .order('unvan'),
        SupabaseService.supabase
            .from('finans_transfer')
            .select()
            .order('tarih', ascending: false)
            .limit(100),
        SupabaseService.supabase
            .from('cari_virman')
            .select()
            .order('tarih', ascending: false)
            .limit(100),
      ]);

      if (!mounted) return;

      setState(() {
        _kasalar = List<Map<String, dynamic>>.from(sonuclar[0] as List);

        _kasaBakiyeleri.clear();

        final kasaHareketleri = List<Map<String, dynamic>>.from(
          sonuclar[1] as List,
        );

        for (final hareket in kasaHareketleri) {
          final kasaId =
              int.tryParse(hareket['kasa_id']?.toString() ?? '') ?? 0;

          if (kasaId <= 0) {
            continue;
          }

          final tip = _metin(hareket['tip']).toUpperCase();

          final tutar = _sayi(hareket['tutar']);

          final girisMi = tip == 'GIRIS' || tip == 'GİRİŞ';

          _kasaBakiyeleri[kasaId] =
              (_kasaBakiyeleri[kasaId] ?? 0) + (girisMi ? tutar : -tutar);
        }

        _cariler = List<Map<String, dynamic>>.from(sonuclar[2] as List)
            .where((cari) {
              final aktif = cari['aktif']?.toString().toLowerCase();

              return aktif == null ||
                  aktif == 'true' ||
                  aktif == '1' ||
                  aktif == 'aktif' ||
                  aktif == 'evet';
            })
            .toList();

        _transferler = List<Map<String, dynamic>>.from(sonuclar[3] as List);

        _virmanlar = List<Map<String, dynamic>>.from(sonuclar[4] as List);

        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      _mesaj('Transfer / virman verileri yüklenemedi: $e', Colors.red);
    }
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  Map<String, dynamic>? _kasaBul(int? id) {
    if (id == null) return null;

    for (final kasa in _kasalar) {
      if (int.tryParse(kasa['kasa_id']?.toString() ?? '') == id) {
        return kasa;
      }
    }

    return null;
  }

  double _kasaBakiyesi(int? kasaId) {
    if (kasaId == null) {
      return 0;
    }

    return _kasaBakiyeleri[kasaId] ?? 0;
  }

  Color _bakiyeRengi(double bakiye) {
    if (bakiye > 0) {
      return Colors.green.shade700;
    }

    if (bakiye < 0) {
      return Colors.red.shade700;
    }

    return Colors.grey.shade700;
  }

  String _bakiyeMetni(int? kasaId) {
    final bakiye = _kasaBakiyesi(kasaId);

    if (bakiye > 0) {
      return 'Bakiye: +${_para(bakiye)}';
    }

    if (bakiye < 0) {
      return 'Bakiye: -${_para(bakiye.abs())}';
    }

    return 'Bakiye: ${_para(0)}';
  }

  Map<String, dynamic>? _cariBul(int? id) {
    if (id == null) return null;

    for (final cari in _cariler) {
      if (int.tryParse(cari['cari_id']?.toString() ?? '') == id) {
        return cari;
      }
    }

    return null;
  }

  String _cariBakiyeDurumu(Map<String, dynamic>? cari) {
    if (cari == null) return '-';

    final tip = _metin(cari['cari_tipi']).toUpperCase();

    final bakiye = _sayi(cari['bakiye']);

    if (bakiye == 0) {
      return 'Hesap Kapalı';
    }

    if (tip.contains('TEDAR')) {
      return bakiye > 0 ? 'Tedarikçiye Borç' : 'Tedarikçiden Alacak';
    }

    if (tip.contains('MUSTERI') || tip.contains('MÜŞTERİ')) {
      return bakiye > 0 ? 'Müşteriden Alacak' : 'Müşteriye Borç';
    }

    return bakiye > 0 ? 'Cariden Alacak' : 'Cariye Borç';
  }

  Future<int?> _kasaSec({required String baslik, int? haricKasaId}) async {
    final arama = TextEditingController();

    try {
      return await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final q = arama.text.toLowerCase().trim();

              final liste = _kasalar.where((kasa) {
                final id = int.tryParse(kasa['kasa_id']?.toString() ?? '');

                if (id == haricKasaId) {
                  return false;
                }

                if (q.isEmpty) return true;

                return [kasa['kasa_adi'], kasa['kasa_tipi']]
                    .map((e) => e?.toString() ?? '')
                    .join(' ')
                    .toLowerCase()
                    .contains(q);
              }).toList();

              return AlertDialog(
                title: Text(baslik),
                content: MobilDialogIcerik(
                  width: 620,
                  height: 520,
                  child: Column(
                    children: [
                      TextField(
                        controller: arama,
                        autofocus: true,
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                        decoration: const InputDecoration(
                          hintText: 'Kasa, banka, POS veya kredi kartı ara...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          itemCount: liste.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final kasa = liste[index];

                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                              ),
                              title: Text(
                                _metin(kasa['kasa_adi']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Tip: ${_metin(kasa['kasa_tipi'])}\n'
                                '${_bakiyeMetni(int.tryParse(kasa['kasa_id'].toString()))}',
                              ),
                              isThreeLine: true,
                              trailing: MobilYatayRow(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _para(
                                      _kasaBakiyesi(
                                        int.tryParse(
                                          kasa['kasa_id'].toString(),
                                        ),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _bakiyeRengi(
                                        _kasaBakiyesi(
                                          int.tryParse(
                                            kasa['kasa_id'].toString(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(
                                  dialogContext,
                                  int.tryParse(kasa['kasa_id'].toString()),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      arama.dispose();
    }
  }

  Future<int?> _cariSec({
    required String baslik,
    required bool musteri,
    int? haricCariId,
  }) async {
    final arama = TextEditingController();

    try {
      return await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final q = arama.text.toLowerCase().trim();

              final liste = _cariler.where((cari) {
                final id = int.tryParse(cari['cari_id']?.toString() ?? '');

                if (id == haricCariId) {
                  return false;
                }

                final tip = _metin(cari['cari_tipi']).toUpperCase();

                if (musteri &&
                    !(tip.contains('MUSTERI') || tip.contains('MÜŞTERİ'))) {
                  return false;
                }

                if (!musteri && !tip.contains('TEDAR')) {
                  return false;
                }

                if (q.isEmpty) return true;

                return [cari['unvan'], cari['cari_tipi'], cari['cari_id']]
                    .map((e) => e?.toString() ?? '')
                    .join(' ')
                    .toLowerCase()
                    .contains(q);
              }).toList();

              return AlertDialog(
                title: Text(baslik),
                content: MobilDialogIcerik(
                  width: 720,
                  height: 560,
                  child: Column(
                    children: [
                      TextField(
                        controller: arama,
                        autofocus: true,
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                        decoration: const InputDecoration(
                          hintText: 'Cari ünvanı / tipi ara...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          itemCount: liste.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final cari = liste[index];

                            final bakiye = _sayi(cari['bakiye']);

                            final bakiyeRenk = bakiye > 0
                                ? Colors.green.shade700
                                : bakiye < 0
                                ? Colors.red.shade700
                                : Colors.grey.shade700;

                            final bakiyeMetni = bakiye > 0
                                ? '+ ${_para(bakiye)}'
                                : bakiye < 0
                                ? '- ${_para(bakiye.abs())}'
                                : _para(0);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: musteri
                                    ? Colors.blue.shade50
                                    : Colors.orange.shade50,
                                child: Icon(
                                  musteri
                                      ? Icons.person_outline
                                      : Icons.local_shipping_outlined,
                                  color: musteri
                                      ? Colors.blue.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                              title: Text(
                                _metin(cari['unvan']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tip: ${_metin(cari['cari_tipi'])}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _cariBakiyeDurumu(cari),
                                    style: TextStyle(
                                      color: bakiyeRenk,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: MobilYatayRow(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        bakiyeMetni,
                                        style: TextStyle(
                                          color: bakiyeRenk,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        bakiye > 0
                                            ? (musteri
                                                  ? 'Alacağınız var'
                                                  : 'Borç mevcut')
                                            : bakiye < 0
                                            ? (musteri
                                                  ? 'Borcunuz var'
                                                  : 'Alacağınız var')
                                            : 'Hesap kapalı',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(
                                  dialogContext,
                                  int.tryParse(cari['cari_id'].toString()),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: MobilYatayRow(
                          children: [
                            Expanded(
                              child: MobilYatayRow(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: Colors.green.shade50,
                                    child: Icon(
                                      Icons.arrow_upward,
                                      size: 15,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  const Expanded(
                                    child: Text(
                                      'Pozitif bakiye',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: MobilYatayRow(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: Colors.red.shade50,
                                    child: Icon(
                                      Icons.arrow_downward,
                                      size: 15,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  const Expanded(
                                    child: Text(
                                      'Negatif bakiye',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: MobilYatayRow(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: Colors.grey.shade200,
                                    child: Icon(
                                      Icons.remove,
                                      size: 15,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  const Expanded(
                                    child: Text(
                                      'Sıfır bakiye',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
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
        },
      );
    } finally {
      arama.dispose();
    }
  }

  Future<void> _tarihSec({required bool transfer}) async {
    final mevcut = transfer ? _transferTarih : _virmanTarih;

    final tarih = await showDatePicker(
      context: context,
      initialDate: mevcut,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (tarih == null || !mounted) {
      return;
    }

    setState(() {
      final yeni = DateTime(
        tarih.year,
        tarih.month,
        tarih.day,
        DateTime.now().hour,
        DateTime.now().minute,
      );

      if (transfer) {
        _transferTarih = yeni;
      } else {
        _virmanTarih = yeni;
      }
    });
  }

  Future<void> _transferKaydet() async {
    final kaynak = _kasaBul(_kaynakKasaId);

    final hedef = _kasaBul(_hedefKasaId);

    final tutar = _sayi(_transferTutar.text);

    if (kaynak == null || hedef == null) {
      _mesaj('Kaynak ve hedef hesabı seçmelisiniz.', Colors.orange);
      return;
    }

    if (_kaynakKasaId == _hedefKasaId) {
      _mesaj('Kaynak ve hedef hesap aynı olamaz.', Colors.orange);
      return;
    }

    if (tutar <= 0) {
      _mesaj('Transfer tutarı sıfırdan büyük olmalıdır.', Colors.orange);
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Transferi Onayla'),
          content: Text(
            'Kaynak: ${_metin(kaynak['kasa_adi'])}\n'
            '${_bakiyeMetni(_kaynakKasaId)} → '
            '${_para(_kasaBakiyesi(_kaynakKasaId) - tutar)}\n\n'
            'Hedef: ${_metin(hedef['kasa_adi'])}\n'
            '${_bakiyeMetni(_hedefKasaId)} → '
            '${_para(_kasaBakiyesi(_hedefKasaId) + tutar)}\n\n'
            'Transfer Tutarı: ${_para(tutar)}\n\n'
            'Kaynak hesaptan çıkış ve hedef hesaba giriş '
            'hareketi oluşturulacak.',
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
              child: const Text('Transfer Yap'),
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
      final sonuc = await SupabaseService.supabase.rpc(
        'finans_hesap_transfer_kaydet',
        params: {
          'p_kaynak_kasa_id': _kaynakKasaId,
          'p_hedef_kasa_id': _hedefKasaId,
          'p_tutar': tutar,
          'p_aciklama': _transferAciklama.text.trim(),
          'p_tarih': _transferTarih.toUtc().toIso8601String(),
          'p_kullanici': YetkiService.aktifKullanici,
        },
      );

      if (!mounted) return;

      _mesaj('Transfer kaydedildi. Belge: ${_metin(sonuc)}', Colors.green);

      _transferTutar.clear();
      _transferAciklama.clear();

      setState(() {
        _kaynakKasaId = null;
        _hedefKasaId = null;
      });

      await _verileriYukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj('Transfer kaydedilemedi: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _kaydediliyor = false;
        });
      }
    }
  }

  Future<void> _virmanKaydet() async {
    final musteri = _cariBul(_musteriCariId);

    final tedarikci = _cariBul(_tedarikciCariId);

    final tutar = _sayi(_virmanTutar.text);

    if (musteri == null || tedarikci == null) {
      _mesaj('Müşteri ve tedarikçi seçmelisiniz.', Colors.orange);
      return;
    }

    if (_musteriCariId == _tedarikciCariId) {
      _mesaj('Aynı cari kendi kendine virman yapılamaz.', Colors.orange);
      return;
    }

    if (tutar <= 0) {
      _mesaj('Virman tutarı sıfırdan büyük olmalıdır.', Colors.orange);
      return;
    }

    final musteriBakiye = _sayi(musteri['bakiye']);

    final tedarikciBakiye = _sayi(tedarikci['bakiye']);

    if (musteriBakiye <= 0) {
      _mesaj('Seçilen müşterinin size borcu görünmüyor.', Colors.orange);
      return;
    }

    if (tedarikciBakiye <= 0) {
      _mesaj('Seçilen tedarikçiye borcunuz görünmüyor.', Colors.orange);
      return;
    }

    if (tutar > musteriBakiye || tutar > tedarikciBakiye) {
      _mesaj(
        'Virman tutarı müşteri veya tedarikçi açık bakiyesinden fazla olamaz.',
        Colors.orange,
      );
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Virmanı Onayla'),
          content: Text(
            'Müşteri: ${_metin(musteri['unvan'])}\n'
            'Müşteri borcu: ${_para(musteriBakiye)} → '
            '${_para(musteriBakiye - tutar)}\n\n'
            'Tedarikçi: ${_metin(tedarikci['unvan'])}\n'
            'Tedarikçi borcu: ${_para(tedarikciBakiye)} → '
            '${_para(tedarikciBakiye - tutar)}\n\n'
            'Virman: ${_para(tutar)}\n\n'
            'Kasa / banka hareketi oluşmayacak.',
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
              child: const Text('Virman Yap'),
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
      final sonuc = await SupabaseService.supabase.rpc(
        'cari_virman_kaydet',
        params: {
          'p_musteri_cari_id': _musteriCariId,
          'p_tedarikci_cari_id': _tedarikciCariId,
          'p_tutar': tutar,
          'p_aciklama': _virmanAciklama.text.trim(),
          'p_tarih': _virmanTarih.toUtc().toIso8601String(),
          'p_kullanici': YetkiService.aktifKullanici,
        },
      );

      if (!mounted) return;

      _mesaj('Virman kaydedildi. Belge: ${_metin(sonuc)}', Colors.green);

      _virmanTutar.clear();
      _virmanAciklama.clear();

      setState(() {
        _musteriCariId = null;
        _tedarikciCariId = null;
      });

      await _verileriYukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj('Virman kaydedilemedi: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _kaydediliyor = false;
        });
      }
    }
  }

  Widget _secimKarti({
    required String baslik,
    required String deger,
    required String altYazi,
    required IconData ikon,
    required VoidCallback onTap,
    Color renk = Colors.blue,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: renk.withOpacity(0.28)),
          color: renk.withOpacity(0.04),
        ),
        child: MobilYatayRow(
          children: [
            CircleAvatar(
              backgroundColor: renk.withOpacity(0.12),
              child: Icon(ikon, color: renk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    deger,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    altYazi,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.search_rounded),
          ],
        ),
      ),
    );
  }

  Widget _transferFormu() {
    final kaynak = _kasaBul(_kaynakKasaId);
    final hedef = _kasaBul(_hedefKasaId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MobilYatayRow(
                    children: [
                      Icon(Icons.swap_horiz_rounded),
                      SizedBox(width: 8),
                      Text(
                        'HESAPLAR ARASI TRANSFER',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nakit → Banka, Banka → Nakit, '
                    'Banka → Kredi Kartı, Nakit → Kredi Kartı, '
                    'POS → Banka gibi tüm hesap transferleri.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 18),
                  MobilYatayRow(
                    mobilDikey: true,
                    children: [
                      Expanded(
                        child: _secimKarti(
                          baslik: 'KAYNAK HESAP',
                          deger: kaynak == null
                              ? 'Hesap seç'
                              : _metin(kaynak['kasa_adi']),
                          altYazi: kaynak == null
                              ? 'Bu hesaptan para çıkacak'
                              : '${_metin(kaynak['kasa_tipi'])} • ${_bakiyeMetni(_kaynakKasaId)}',
                          ikon: Icons.north_east_rounded,
                          renk: Colors.red,
                          onTap: () async {
                            final id = await _kasaSec(
                              baslik: 'Kaynak Hesabı Seç',
                              haricKasaId: _hedefKasaId,
                            );

                            if (id == null || !mounted) {
                              return;
                            }

                            setState(() {
                              _kaynakKasaId = id;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.arrow_forward_rounded, size: 34),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _secimKarti(
                          baslik: 'HEDEF HESAP',
                          deger: hedef == null
                              ? 'Hesap seç'
                              : _metin(hedef['kasa_adi']),
                          altYazi: hedef == null
                              ? 'Bu hesaba para girecek'
                              : '${_metin(hedef['kasa_tipi'])} • ${_bakiyeMetni(_hedefKasaId)}',
                          ikon: Icons.south_west_rounded,
                          renk: Colors.green,
                          onTap: () async {
                            final id = await _kasaSec(
                              baslik: 'Hedef Hesabı Seç',
                              haricKasaId: _kaynakKasaId,
                            );

                            if (id == null || !mounted) {
                              return;
                            }

                            setState(() {
                              _hedefKasaId = id;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MobilYatayRow(
                    mobilDikey: true,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _transferTutar,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Transfer Tutarı',
                            suffixText: '₺',
                            prefixIcon: Icon(Icons.payments_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 220,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _tarihSec(transfer: true);
                          },
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            '${_transferTarih.day.toString().padLeft(2, '0')}.'
                            '${_transferTarih.month.toString().padLeft(2, '0')}.'
                            '${_transferTarih.year}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _transferAciklama,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      hintText: 'Örn: Nakit ile Garanti K.K borç ödemesi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _kaydediliyor ? null : _transferKaydet,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(
                        _kaydediliyor ? 'Kaydediliyor...' : 'TRANSFER YAP',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _transferGecmisi(),
        ],
      ),
    );
  }

  Widget _virmanFormu() {
    final musteri = _cariBul(_musteriCariId);
    final tedarikci = _cariBul(_tedarikciCariId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MobilYatayRow(
                    children: [
                      Icon(Icons.compare_arrows_rounded),
                      SizedBox(width: 8),
                      Text(
                        'CARİ VİRMAN / MAHSUP',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Müşterinin size olan borcu ile sizin '
                    'tedarikçiye olan borcunuzu mahsup eder. '
                    'Kasa / banka hareketi oluşturmaz.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 18),
                  MobilYatayRow(
                    mobilDikey: true,
                    children: [
                      Expanded(
                        child: _secimKarti(
                          baslik: 'BORCU AZALACAK MÜŞTERİ',
                          deger: musteri == null
                              ? 'Müşteri seç'
                              : _metin(musteri['unvan']),
                          altYazi: musteri == null
                              ? 'Müşteriden alacağınız azalır'
                              : '${_cariBakiyeDurumu(musteri)} • '
                                    '${_sayi(musteri['bakiye']) > 0
                                        ? '+'
                                        : _sayi(musteri['bakiye']) < 0
                                        ? '-'
                                        : ''}'
                                    '${_para(_sayi(musteri['bakiye']).abs())}',
                          ikon: Icons.person_outline,
                          renk: Colors.blue,
                          onTap: () async {
                            final id = await _cariSec(
                              baslik: 'Müşteri Seç',
                              musteri: true,
                              haricCariId: _tedarikciCariId,
                            );

                            if (id == null || !mounted) {
                              return;
                            }

                            setState(() {
                              _musteriCariId = id;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.compare_arrows_rounded, size: 34),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _secimKarti(
                          baslik: 'BORCU AZALACAK TEDARİKÇİ',
                          deger: tedarikci == null
                              ? 'Tedarikçi seç'
                              : _metin(tedarikci['unvan']),
                          altYazi: tedarikci == null
                              ? 'Tedarikçiye borcunuz azalır'
                              : '${_cariBakiyeDurumu(tedarikci)} • '
                                    '${_sayi(tedarikci['bakiye']) > 0
                                        ? '+'
                                        : _sayi(tedarikci['bakiye']) < 0
                                        ? '-'
                                        : ''}'
                                    '${_para(_sayi(tedarikci['bakiye']).abs())}',
                          ikon: Icons.local_shipping_outlined,
                          renk: Colors.orange,
                          onTap: () async {
                            final id = await _cariSec(
                              baslik: 'Tedarikçi Seç',
                              musteri: false,
                              haricCariId: _musteriCariId,
                            );

                            if (id == null || !mounted) {
                              return;
                            }

                            setState(() {
                              _tedarikciCariId = id;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MobilYatayRow(
                    mobilDikey: true,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _virmanTutar,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Virman Tutarı',
                            suffixText: '₺',
                            prefixIcon: Icon(Icons.payments_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 220,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _tarihSec(transfer: false);
                          },
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            '${_virmanTarih.day.toString().padLeft(2, '0')}.'
                            '${_virmanTarih.month.toString().padLeft(2, '0')}.'
                            '${_virmanTarih.year}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _virmanAciklama,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      hintText:
                          'Örn: Müşteri K.K ile tedarikçi borcu mahsup edildi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _kaydediliyor ? null : _virmanKaydet,
                      icon: const Icon(Icons.compare_arrows_rounded),
                      label: Text(
                        _kaydediliyor ? 'Kaydediliyor...' : 'VİRMAN YAP',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _virmanGecmisi(),
        ],
      ),
    );
  }

  Future<void> _transferDetayGoster(Map<String, dynamic> transfer) async {
    final kaynak = _kasaBul(
      int.tryParse(transfer['kaynak_kasa_id']?.toString() ?? ''),
    );

    final hedef = _kasaBul(
      int.tryParse(transfer['hedef_kasa_id']?.toString() ?? ''),
    );

    final tutar = _sayi(transfer['tutar']);

    final kaynakId = int.tryParse(transfer['kaynak_kasa_id']?.toString() ?? '');

    final hedefId = int.tryParse(transfer['hedef_kasa_id']?.toString() ?? '');

    final kaynakGuncel = _kasaBakiyesi(kaynakId);
    final hedefGuncel = _kasaBakiyesi(hedefId);

    // Geçmiş transfer kaydında işlem öncesi bakiye ayrıca tutulmuyorsa,
    // mevcut hareketlerden kesin geçmiş bakiye üretmek güvenilir değildir.
    // Bu nedenle detayda güncel bakiye gösterilir.
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: MobilDialogIcerik(
            width: 920,
            height: 660,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  color: Colors.blueGrey.shade800,
                  child: MobilYatayRow(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transfer Detayı: ${_metin(transfer['transfer_no'])}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Hesaplar Arası Transfer',
                              style: TextStyle(color: Colors.white70),
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
                  padding: const EdgeInsets.all(16),
                  child: MobilYatayRow(
                    children: [
                      Expanded(
                        child: _virmanBilgiKarti(
                          baslik: 'Transfer No',
                          deger: _metin(transfer['transfer_no']),
                          ikon: Icons.receipt_long_outlined,
                          renk: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _virmanBilgiKarti(
                          baslik: 'Tarih / Saat',
                          deger: _tarih(transfer['tarih']),
                          ikon: Icons.calendar_month_outlined,
                          renk: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _virmanBilgiKarti(
                          baslik: 'Transfer Tutarı',
                          deger: _para(tutar),
                          ikon: Icons.payments_outlined,
                          renk: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MobilYatayRow(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Card(
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MobilYatayRow(
                                  children: [
                                    Icon(
                                      Icons.north_east_rounded,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'KAYNAK HESAP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _metin(kaynak?['kasa_adi']),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('Tip: ${_metin(kaynak?['kasa_tipi'])}'),
                                const SizedBox(height: 6),
                                Text(
                                  'Transfer Çıkışı: -${_para(tutar)}',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Güncel Bakiye: ${_para(kaynakGuncel)}',
                                  style: TextStyle(
                                    color: _bakiyeRengi(kaynakGuncel),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Padding(
                        padding: EdgeInsets.only(top: 52),
                        child: Icon(Icons.arrow_forward_rounded, size: 38),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Card(
                          color: Colors.green.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MobilYatayRow(
                                  children: [
                                    Icon(
                                      Icons.south_west_rounded,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'HEDEF HESAP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _metin(hedef?['kasa_adi']),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('Tip: ${_metin(hedef?['kasa_tipi'])}'),
                                const SizedBox(height: 6),
                                Text(
                                  'Transfer Girişi: +${_para(tutar)}',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Güncel Bakiye: ${_para(hedefGuncel)}',
                                  style: TextStyle(
                                    color: _bakiyeRengi(hedefGuncel),
                                    fontWeight: FontWeight.w600,
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
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MobilYatayRow(
                            children: [
                              Icon(Icons.notes_rounded),
                              SizedBox(width: 8),
                              Text(
                                'AÇIKLAMA',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SelectableText(_metin(transfer['aciklama'])),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: MobilYatayRow(
                    children: [
                      Text(
                        'Kullanıcı: ${_metin(transfer['kullanici'])}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () {
                          final metin =
                              'TRANSFER DETAYI\n'
                              'Transfer No: ${_metin(transfer['transfer_no'])}\n'
                              'Tarih: ${_tarih(transfer['tarih'])}\n'
                              'Kaynak: ${_metin(kaynak?['kasa_adi'])}\n'
                              'Hedef: ${_metin(hedef?['kasa_adi'])}\n'
                              'Tutar: ${_para(tutar)}\n'
                              'Açıklama: ${_metin(transfer['aciklama'])}\n'
                              'Kullanıcı: ${_metin(transfer['kullanici'])}';

                          Clipboard.setData(ClipboardData(text: metin));

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Transfer detayları panoya kopyalandı.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_all_rounded),
                        label: const Text('Tümünü Kopyala'),
                      ),
                      const SizedBox(width: 8),
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

  Widget _transferGecmisi() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SON HESAP TRANSFERLERİ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (_transferler.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: Text('Transfer kaydı yok.')),
              )
            else
              ..._transferler.take(20).map((x) {
                final kaynak = _kasaBul(
                  int.tryParse(x['kaynak_kasa_id']?.toString() ?? ''),
                );

                final hedef = _kasaBul(
                  int.tryParse(x['hedef_kasa_id']?.toString() ?? ''),
                );

                return Card(
                  elevation: 0.5,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    onTap: () {
                      _transferDetayGoster(x);
                    },
                    leading: const CircleAvatar(
                      child: Icon(Icons.swap_horiz_rounded),
                    ),
                    title: Text(
                      '${_metin(kaynak?['kasa_adi'])} → '
                      '${_metin(hedef?['kasa_adi'])}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${_metin(x['transfer_no'])} • '
                      '${_tarih(x['tarih'])}\n'
                      '${_metin(x['aciklama'])}',
                    ),
                    trailing: MobilYatayRow(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _para(x['tutar']),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _virmanDetayGoster(Map<String, dynamic> virman) async {
    final musteri = _cariBul(
      int.tryParse(virman['musteri_cari_id']?.toString() ?? ''),
    );

    final tedarikci = _cariBul(
      int.tryParse(virman['tedarikci_cari_id']?.toString() ?? ''),
    );

    final tutar = _sayi(virman['tutar']);

    // Yeni kayıtlarda işlem anındaki bakiyeler virman tablosunda tutuluyorsa
    // doğrudan onları kullan. Eski kayıtlarda bu alanlar yoksa mevcut cari
    // bakiyesinden hareketle detay ekranı için geriye doğru hesapla.
    double bakiyeAl(List<String> alanlar, double varsayilan) {
      for (final alan in alanlar) {
        final deger = virman[alan];
        if (deger != null && deger.toString().trim().isNotEmpty) {
          return _sayi(deger);
        }
      }
      return varsayilan;
    }

    final musteriGuncel = _sayi(musteri?['bakiye']);
    final tedarikciGuncel = _sayi(tedarikci?['bakiye']);

    final musteriSonrasi = bakiyeAl(const [
      'musteri_sonrasi_bakiye',
      'musteri_bakiye_sonra',
      'musteri_son_bakiye',
    ], musteriGuncel);
    final musteriOncesi = bakiyeAl(const [
      'musteri_oncesi_bakiye',
      'musteri_bakiye_once',
      'musteri_onceki_bakiye',
    ], musteriSonrasi + tutar);

    final tedarikciSonrasi = bakiyeAl(const [
      'tedarikci_sonrasi_bakiye',
      'tedarikci_bakiye_sonra',
      'tedarikci_son_bakiye',
    ], tedarikciGuncel);
    final tedarikciOncesi = bakiyeAl(const [
      'tedarikci_oncesi_bakiye',
      'tedarikci_bakiye_once',
      'tedarikci_onceki_bakiye',
    ], tedarikciSonrasi + tutar);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: MobilDialogIcerik(
            width: 900,
            height: 620,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  color: Colors.blueGrey.shade800,
                  child: MobilYatayRow(
                    children: [
                      const Icon(
                        Icons.compare_arrows_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Virman Detayı: ${_metin(virman['virman_no'])}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Cari Virman / Mahsup',
                              style: TextStyle(color: Colors.white70),
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
                  padding: const EdgeInsets.all(16),
                  child: MobilYatayRow(
                    children: [
                      Expanded(
                        child: _virmanBilgiKarti(
                          baslik: 'Virman No',
                          deger: _metin(virman['virman_no']),
                          ikon: Icons.receipt_long_outlined,
                          renk: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _virmanBilgiKarti(
                          baslik: 'Tarih / Saat',
                          deger: _tarih(virman['tarih']),
                          ikon: Icons.calendar_month_outlined,
                          renk: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _virmanBilgiKarti(
                          baslik: 'Virman Tutarı',
                          deger: _para(tutar),
                          ikon: Icons.payments_outlined,
                          renk: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MobilYatayRow(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MobilYatayRow(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'MÜŞTERİ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _metin(musteri?['unvan']),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Cari Tipi: ${_metin(musteri?['cari_tipi'])}',
                                ),
                                const SizedBox(height: 12),
                                _virmanBakiyeSatiri(
                                  'İşlem Öncesi Bakiye',
                                  musteriOncesi,
                                ),
                                const SizedBox(height: 7),
                                _virmanBakiyeSatiri(
                                  'Virman Değişimi',
                                  -tutar,
                                  renk: Colors.red.shade700,
                                ),
                                const Divider(height: 18),
                                _virmanBakiyeSatiri(
                                  'İşlem Sonrası Bakiye',
                                  musteriSonrasi,
                                  kalin: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Icon(Icons.compare_arrows_rounded, size: 38),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Card(
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MobilYatayRow(
                                  children: [
                                    Icon(
                                      Icons.local_shipping_outlined,
                                      color: Colors.orange.shade800,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'TEDARİKÇİ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _metin(tedarikci?['unvan']),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Cari Tipi: ${_metin(tedarikci?['cari_tipi'])}',
                                ),
                                const SizedBox(height: 12),
                                _virmanBakiyeSatiri(
                                  'İşlem Öncesi Bakiye',
                                  tedarikciOncesi,
                                ),
                                const SizedBox(height: 7),
                                _virmanBakiyeSatiri(
                                  'Virman Değişimi',
                                  -tutar,
                                  renk: Colors.red.shade700,
                                ),
                                const Divider(height: 18),
                                _virmanBakiyeSatiri(
                                  'İşlem Sonrası Bakiye',
                                  tedarikciSonrasi,
                                  kalin: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MobilYatayRow(
                            children: [
                              Icon(Icons.notes_rounded),
                              SizedBox(width: 8),
                              Text(
                                'AÇIKLAMA',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SelectableText(_metin(virman['aciklama'])),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: MobilYatayRow(
                    children: [
                      Text(
                        'Kullanıcı: ${_metin(virman['kullanici'])}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () {
                          final metin =
                              'VİRMAN DETAYI\n'
                              'Virman No: ${_metin(virman['virman_no'])}\n'
                              'Tarih: ${_tarih(virman['tarih'])}\n'
                              'Müşteri: ${_metin(musteri?['unvan'])}\n'
                              'Müşteri İşlem Öncesi: ${_para(musteriOncesi)}\n'
                              'Müşteri Virman Değişimi: -${_para(tutar)}\n'
                              'Müşteri İşlem Sonrası: ${_para(musteriSonrasi)}\n'
                              'Tedarikçi: ${_metin(tedarikci?['unvan'])}\n'
                              'Tedarikçi İşlem Öncesi: ${_para(tedarikciOncesi)}\n'
                              'Tedarikçi Virman Değişimi: -${_para(tutar)}\n'
                              'Tedarikçi İşlem Sonrası: ${_para(tedarikciSonrasi)}\n'
                              'Tutar: ${_para(tutar)}\n'
                              'Açıklama: ${_metin(virman['aciklama'])}\n'
                              'Kullanıcı: ${_metin(virman['kullanici'])}';

                          Clipboard.setData(ClipboardData(text: metin));

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Virman detayları panoya kopyalandı.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_all_rounded),
                        label: const Text('Tümünü Kopyala'),
                      ),
                      const SizedBox(width: 8),
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

  Widget _virmanBakiyeSatiri(
    String baslik,
    double bakiye, {
    Color? renk,
    bool kalin = false,
  }) {
    final isaret = bakiye > 0
        ? '+'
        : bakiye < 0
        ? '-'
        : '';

    return MobilYatayRow(
      children: [
        Expanded(
          child: Text(
            baslik,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: kalin ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          '$isaret${_para(bakiye.abs())}',
          style: TextStyle(
            color: renk ?? _bakiyeRengi(bakiye),
            fontWeight: kalin ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _virmanBilgiKarti({
    required String baslik,
    required String deger,
    required IconData ikon,
    required Color renk,
  }) {
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: renk,
                    fontSize: 15,
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

  Widget _virmanGecmisi() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SON CARİ VİRMANLAR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (_virmanlar.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: Text('Virman kaydı yok.')),
              )
            else
              ..._virmanlar.take(20).map((x) {
                final musteri = _cariBul(
                  int.tryParse(x['musteri_cari_id']?.toString() ?? ''),
                );

                final tedarikci = _cariBul(
                  int.tryParse(x['tedarikci_cari_id']?.toString() ?? ''),
                );

                return Card(
                  elevation: 0.5,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    onTap: () {
                      _virmanDetayGoster(x);
                    },
                    leading: const CircleAvatar(
                      child: Icon(Icons.compare_arrows_rounded),
                    ),
                    title: Text(
                      '${_metin(musteri?['unvan'])} ↔ '
                      '${_metin(tedarikci?['unvan'])}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${_metin(x['virman_no'])} • '
                      '${_tarih(x['tarih'])}\n'
                      '${_metin(x['aciklama'])}',
                    ),
                    trailing: MobilYatayRow(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _para(x['tutar']),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              }),
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
          'TRANSFER / VİRMAN',
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.swap_horiz_rounded),
              text: 'Hesaplar Arası Transfer',
            ),
            Tab(
              icon: Icon(Icons.compare_arrows_rounded),
              text: 'Cari Virman / Mahsup',
            ),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_transferFormu(), _virmanFormu()],
            ),
    );
  }
}
