// lib/screens/satis_irsaliyeleri_screen.dart

import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../services/yetki_service.dart';
import '../services/belge_pdf_service.dart';
import '../services/firma_ayarlari_service.dart';
import '../services/calisma_sekmesi_service.dart';
import '../utils/marka_kod.dart';
import 'yeni_satis_irsaliyesi_screen.dart';

class SatisIrsaliyeleriScreen extends StatefulWidget {
  const SatisIrsaliyeleriScreen({super.key});

  @override
  State<SatisIrsaliyeleriScreen> createState() =>
      _SatisIrsaliyeleriScreenState();
}

class _SatisIrsaliyeleriScreenState extends State<SatisIrsaliyeleriScreen> {
  bool _yukleniyor = true;
  bool _islem = false;

  String _durum = 'TÜMÜ';

  final TextEditingController _aramaController = TextEditingController();

  List<Map<String, dynamic>> _tum = [];
  List<Map<String, dynamic>> _gorunen = [];

  Map<int, String> _cariler = {};
  Map<int, String> _depolar = {};

  List<Map<String, dynamic>> _kasalar = [];

  final Set<int> _secilenIrsaliyeIds = <int>{};

  @override
  void initState() {
    super.initState();
    _aramaController.addListener(_filtrele);
    _yukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  String _m(dynamic deger) {
    final metin = deger?.toString().trim() ?? '';
    return metin.isEmpty ? '-' : metin;
  }

  double _s(dynamic deger) {
    return double.tryParse((deger ?? 0).toString().replaceAll(',', '.')) ?? 0.0;
  }

  String _para(dynamic deger) {
    return '${_s(deger).toStringAsFixed(2)} ₺';
  }

  String _miktar(dynamic deger) {
    final sayi = _s(deger);

    if (sayi == sayi.roundToDouble()) {
      return sayi.toStringAsFixed(0);
    }

    return sayi.toStringAsFixed(3);
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

  Color _durumRengi(dynamic durum) {
    switch (_m(durum).toUpperCase()) {
      case 'HAZIRLANIYOR':
        return Colors.orange.shade700;
      case 'ONAYLANDI':
        return Colors.green.shade700;
      case 'FATURALANDI':
        return Colors.blue.shade700;
      case 'IPTAL':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _durumIkonu(dynamic durum) {
    switch (_m(durum).toUpperCase()) {
      case 'HAZIRLANIYOR':
        return Icons.edit_note_rounded;
      case 'ONAYLANDI':
        return Icons.verified_rounded;
      case 'FATURALANDI':
        return Icons.receipt_long_rounded;
      case 'IPTAL':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  int _int(dynamic deger) {
    return int.tryParse(deger?.toString() ?? '') ?? 0;
  }

  String _cariAdi(dynamic cariId) {
    return _cariler[_int(cariId)] ?? '-';
  }

  String _depoAdi(dynamic depoId) {
    return _depolar[_int(depoId)] ?? '-';
  }

  Future<void> _yeniIrsaliyeAc() async {
    final sekmedeAcildi = CalismaSekmesiService.ac(
      'yeni_satis_irsaliyesi',
      'Yeni Satış İrsaliyesi',
      const YeniSatisIrsaliyesiScreen(),
    );
    if (sekmedeAcildi) return;

    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            const YeniSatisIrsaliyesiScreen(kayitSonrasiKapat: true),
      ),
    );

    if (!mounted) return;

    if (sonuc == true) {
      await _yukle();

      _mesaj('Yeni satış irsaliyesi listeye eklendi.', Colors.green);
    }
  }

  Future<void> _konsinyeIrsaliyeAc() async {
    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const YeniSatisIrsaliyesiScreen(
          kayitSonrasiKapat: true,
          konsinye: true,
        ),
      ),
    );

    if (!mounted) return;

    if (sonuc == true) {
      await _yukle();
      _mesaj('Konsinye Çıkış irsaliyesi listeye eklendi.', Colors.teal);
    }
  }

  Future<void> _duzeltAc(Map<String, dynamic> irsaliye) async {
    final durum = _m(irsaliye['durum']).toUpperCase();

    if (durum != 'HAZIRLANIYOR') {
      _mesaj(
        'Sadece HAZIRLANIYOR durumundaki irsaliye düzeltilebilir.',
        Colors.orange,
      );
      return;
    }

    final sonuc = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => YeniSatisIrsaliyesiScreen(
          kayitSonrasiKapat: true,
          duzenlenecekIrsaliye: irsaliye,
        ),
      ),
    );

    if (!mounted) return;

    if (sonuc == true) {
      await _yukle();

      if (!mounted) return;

      _mesaj('Satış irsaliyesi güncellendi.', Colors.green);
    }
  }

  Future<void> _yukle() async {
    if (!mounted) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from('satis_irsaliye_baslik')
            .select()
            .order('tarih', ascending: false),
        SupabaseService.supabase.from('cariler').select('cari_id, unvan'),
        SupabaseService.supabase.from('depolar').select('depo_id, depo_adi'),
        SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi')
            .order('kasa_adi'),
      ]);

      final cariler = <int, String>{};

      for (final cari in List<Map<String, dynamic>>.from(sonuclar[1] as List)) {
        final id = _int(cari['cari_id']);

        if (id > 0) {
          cariler[id] = cari['unvan']?.toString() ?? '';
        }
      }

      final depolar = <int, String>{};

      for (final depo in List<Map<String, dynamic>>.from(sonuclar[2] as List)) {
        final id = _int(depo['depo_id']);

        if (id > 0) {
          depolar[id] = depo['depo_adi']?.toString() ?? '';
        }
      }

      if (!mounted) return;

      setState(() {
        _tum = List<Map<String, dynamic>>.from(sonuclar[0] as List);
        _cariler = cariler;
        _depolar = depolar;
        _kasalar = List<Map<String, dynamic>>.from(sonuclar[3] as List);
        _yukleniyor = false;
      });

      _filtrele();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      _mesaj('İrsaliyeler yüklenemedi: $e', Colors.red);
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
      _gorunen = _tum.where((irsaliye) {
        final durum = _m(irsaliye['durum']).toUpperCase();

        if (_durum != 'TÜMÜ' && durum != _durum) {
          return false;
        }

        if (kelimeler.isEmpty) {
          return true;
        }

        final metin = [
          irsaliye['irsaliye_no'],
          _cariAdi(irsaliye['cari_id']),
          _depoAdi(irsaliye['depo_id']),
          irsaliye['durum'],
          irsaliye['aciklama'],
          irsaliye['kullanici'],
        ].map((deger) => deger?.toString().toLowerCase() ?? '').join(' ');

        return kelimeler.every(metin.contains);
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> _detay(int irsaliyeId) async {
    final detayResponse = await SupabaseService.supabase
        .from('satis_irsaliye_detay')
        .select()
        .eq('irsaliye_id', irsaliyeId)
        .order('detay_id');

    final detaylar = List<Map<String, dynamic>>.from(detayResponse);

    final stokIds = detaylar
        .map((detay) => _int(detay['stok_id']))
        .where((id) => id > 0)
        .toSet()
        .toList();

    final stokHaritasi = <int, Map<String, dynamic>>{};

    if (stokIds.isNotEmpty) {
      final stokResponse = await SupabaseService.supabase
          .from('stoklar')
          .select(
            'stok_id, urun_adi, uretici_kodu, marka, raf, '
            'stok_miktari, alis_fiyati, satis_fiyati_indirimli, '
            'satis_fiyati_toptan, satis_fiyati_perakende, '
            'satis_fiyati_liste, kdv',
          )
          .inFilter('stok_id', stokIds);

      for (final stok in List<Map<String, dynamic>>.from(stokResponse)) {
        final stokId = _int(stok['stok_id']);

        if (stokId > 0) {
          stokHaritasi[stokId] = stok;
        }
      }

      try {
        final oemResponse = await SupabaseService.supabase
            .from('stok_oem')
            .select('stok_id, oem_no')
            .inFilter('stok_id', stokIds);

        final oemHaritasi = <int, List<String>>{};

        for (final oem in List<Map<String, dynamic>>.from(oemResponse)) {
          final stokId = _int(oem['stok_id']);
          final kod = oem['oem_no']?.toString().trim() ?? '';

          if (stokId > 0 && kod.isNotEmpty) {
            oemHaritasi.putIfAbsent(stokId, () => <String>[]).add(kod);
          }
        }

        for (final entry in stokHaritasi.entries) {
          entry.value['oem_no'] = oemHaritasi[entry.key]?.join(', ') ?? '-';
        }
      } catch (_) {
        for (final stok in stokHaritasi.values) {
          stok['oem_no'] = '-';
        }
      }
    }

    for (final detay in detaylar) {
      final stokId = _int(detay['stok_id']);
      final stok = stokHaritasi[stokId];

      detay['urun_adi'] = stok?['urun_adi']?.toString() ?? 'Stok ID: $stokId';

      detay['uretici_kodu'] = stok?['uretici_kodu']?.toString() ?? '-';

      detay['marka'] = stok?['marka']?.toString() ?? '-';

      detay['raf'] = stok?['raf']?.toString() ?? '-';

      detay['oem_no'] = stok?['oem_no']?.toString() ?? '-';

      detay['stok_miktari'] = stok?['stok_miktari'] ?? 0;

      detay['afn'] = stok?['alis_fiyati'] ?? 0;

      detay['sfi'] = stok?['satis_fiyati_indirimli'] ?? 0;

      detay['sft'] = stok?['satis_fiyati_toptan'] ?? 0;

      detay['sfp'] = stok?['satis_fiyati_perakende'] ?? 0;

      detay['sfl'] = stok?['satis_fiyati_liste'] ?? 0;

      detay['stok_kdv'] = stok?['kdv'] ?? detay['kdv_orani'] ?? 0;
    }

    return detaylar;
  }

  double _satirBrut(Map<String, dynamic> detay) {
    return _s(detay['miktar']) * _s(detay['birim_fiyat']);
  }

  double _satirIndirim(Map<String, dynamic> detay) {
    return _satirBrut(detay) * _s(detay['indirim_orani']) / 100;
  }

  double _satirMatrah(Map<String, dynamic> detay) {
    return _satirBrut(detay) - _satirIndirim(detay);
  }

  double _satirKdv(Map<String, dynamic> detay) {
    return _satirMatrah(detay) * _s(detay['kdv_orani']) / 100;
  }

  double _satirToplam(Map<String, dynamic> detay) {
    return _satirMatrah(detay) + _satirKdv(detay);
  }

  Future<void> _onayla(Map<String, dynamic> irsaliye) async {
    setState(() {
      _islem = true;
    });

    try {
      await SupabaseService.supabase.rpc(
        'satis_irsaliye_onayla',
        params: {
          'p_irsaliye_id': irsaliye['irsaliye_id'],
          'p_kullanici': YetkiService.aktifKullanici,
        },
      );

      if (!mounted) return;

      _mesaj('İrsaliye onaylandı.', Colors.green);

      await _yukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj('Onay hatası: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _islem = false;
        });
      }
    }
  }

  Future<void> _iptal(Map<String, dynamic> irsaliye) async {
    final aciklamaController = TextEditingController();

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Satış İrsaliyesini İptal Et'),
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
              icon: const Icon(Icons.cancel_rounded),
              label: const Text('İptal Et'),
            ),
          ],
        );
      },
    );

    final aciklama = aciklamaController.text.trim();

    aciklamaController.dispose();

    if (onay != true) return;

    setState(() {
      _islem = true;
    });

    try {
      await SupabaseService.supabase.rpc(
        'satis_irsaliye_iptal_et',
        params: {
          'p_irsaliye_id': irsaliye['irsaliye_id'],
          'p_kullanici': YetkiService.aktifKullanici,
          'p_aciklama': aciklama.isEmpty
              ? 'Kullanıcı tarafından iptal edildi'
              : aciklama,
        },
      );

      if (!mounted) return;

      _mesaj('İrsaliye iptal edildi.', Colors.green);

      await _yukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj('İptal hatası: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _islem = false;
        });
      }
    }
  }

  Future<void> _faturala(
    Map<String, dynamic> irsaliye,
    List<Map<String, dynamic>> detaylar,
  ) async {
    final id = _int(irsaliye['irsaliye_id']);

    if (id <= 0) return;

    final kalanlar = detaylar
        .where((detay) => _s(detay['kalan_miktar']) > 0)
        .toList();

    if (kalanlar.isEmpty) {
      _mesaj('Faturalanacak kalan miktar yok.', Colors.orange);
      return;
    }

    final miktarControllerlari = <int, TextEditingController>{};

    for (final detay in kalanlar) {
      final detayId = _int(detay['detay_id']);

      miktarControllerlari[detayId] = TextEditingController(
        text: _miktar(detay['kalan_miktar']),
      );
    }

    final faturaNoController = TextEditingController();
    final belgeNoController = TextEditingController();

    String odemeTipi = 'Veresiye';
    int? kasaId;

    try {
      faturaNoController.text = await SupabaseService.yeniBelgeNoGetir(
        belgeTipi: 'SATIS',
      );
    } catch (e) {
      debugPrint('PRO ERP sessiz hata [$e]');
    }

    if (!mounted) return;

    final sonuc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final veresiyeMi = odemeTipi == 'Veresiye';

            return AlertDialog(
              title: MobilYatayRow(
                children: [
                  const Icon(Icons.receipt_long_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'İrsaliyeyi Faturala - '
                      '${_m(irsaliye['irsaliye_no'])}',
                    ),
                  ),
                ],
              ),
              content: MobilDialogIcerik(
                width: 920,
                height: 620,
                child: Column(
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: faturaNoController,
                            decoration: const InputDecoration(
                              labelText: 'Fatura No',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: belgeNoController,
                            decoration: const InputDecoration(
                              labelText: 'Belge No',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 190,
                          child: DropdownButtonFormField<String>(
                            value: odemeTipi,
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
                              if (deger == null) {
                                return;
                              }

                              setDialogState(() {
                                odemeTipi = deger;

                                if (deger == 'Veresiye') {
                                  kasaId = null;
                                } else if (kasaId == null &&
                                    _kasalar.isNotEmpty) {
                                  kasaId = _int(_kasalar.first['kasa_id']);
                                }
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 250,
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
                            items: _kasalar
                                .map(
                                  (kasa) => DropdownMenuItem<int>(
                                    value: _int(kasa['kasa_id']),
                                    child: Text(
                                      kasa['kasa_adi']?.toString() ?? '',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
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
                    Expanded(
                      child: ListView.separated(
                        itemCount: kalanlar.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final detay = kalanlar[index];

                          final detayId = _int(detay['detay_id']);

                          return ListTile(
                            title: Text(
                              _m(detay['urun_adi']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${markaVeUreticiKodu(detay['marka'], detay['uretici_kodu'])} • '
                              'RAF: ${_m(detay['raf'])}\n'
                              'Toplam: ${_miktar(detay['miktar'])} • '
                              'Faturalanan: ${_miktar(detay['faturalanan_miktar'])} • '
                              'Kalan: ${_miktar(detay['kalan_miktar'])}\n'
                              'Birim Fiyat: ${_para(detay['birim_fiyat'])}',
                            ),
                            trailing: SizedBox(
                              width: 125,
                              child: TextField(
                                controller: miktarControllerlari[detayId],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Fatura',
                                  border: OutlineInputBorder(),
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
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Faturayı Oluştur'),
                  onPressed: () {
                    final secilenler = <Map<String, dynamic>>[];

                    for (final detay in kalanlar) {
                      final detayId = _int(detay['detay_id']);

                      final miktar =
                          double.tryParse(
                            miktarControllerlari[detayId]?.text.replaceAll(
                                  ',',
                                  '.',
                                ) ??
                                '0',
                          ) ??
                          0;

                      final kalan = _s(detay['kalan_miktar']);

                      if (miktar < 0 || miktar > kalan) {
                        _mesaj(
                          '${_m(detay['urun_adi'])}: '
                          'Fatura miktarı kalan miktarı aşamaz.',
                          Colors.red,
                        );
                        return;
                      }

                      if (miktar > 0) {
                        secilenler.add({'detay_id': detayId, 'miktar': miktar});
                      }
                    }

                    if (secilenler.isEmpty) {
                      _mesaj('En az bir miktar girin.', Colors.orange);
                      return;
                    }

                    if (!veresiyeMi && kasaId == null) {
                      _mesaj('Peşin işlemde kasa seçin.', Colors.orange);
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'detaylar': secilenler,
                      'odeme_tipi': odemeTipi,
                      'kasa_id': veresiyeMi ? null : kasaId,
                    });
                  },
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

    if (sonuc == null) {
      faturaNoController.dispose();
      belgeNoController.dispose();
      return;
    }

    setState(() {
      _islem = true;
    });

    try {
      final response = await SupabaseService.supabase.rpc(
        'satis_irsaliye_faturala',
        params: {
          'p_irsaliye_id': id,
          'p_kasa_id': sonuc['kasa_id'],
          'p_odeme_tipi': sonuc['odeme_tipi'],
          'p_fatura_no': faturaNoController.text.trim(),
          'p_belge_no': belgeNoController.text.trim(),
          'p_fiyat_tipi': 'PERAKENDE',
          'p_kullanici': YetkiService.aktifKullanici,
          'p_fatura_detaylari': sonuc['detaylar'],
        },
      );

      final satisId = int.tryParse(response?.toString() ?? '');

      if (satisId != null) {
        await SupabaseService.supabase
            .from('satis_baslik')
            .update({
              'irsaliye_id': id,
              'irsaliye_no': irsaliye['irsaliye_no']?.toString(),
            })
            .eq('satis_id', satisId);
      }

      if (!mounted) return;

      _mesaj(
        'Fatura oluşturuldu. Satış ID: '
        '$response',
        Colors.green,
      );

      await _yukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj('Faturalama hatası: $e', Colors.red);
    } finally {
      faturaNoController.dispose();
      belgeNoController.dispose();

      if (mounted) {
        setState(() {
          _islem = false;
        });
      }
    }
  }

  Future<void> _yazdir(
    Map<String, dynamic> irsaliye, {
    required bool musteriKopyasi,
  }) async {
    final id = _int(irsaliye['irsaliye_id']);
    if (id <= 0) {
      _mesaj('Geçersiz satış irsaliyesi.', Colors.red);
      return;
    }
    try {
      if (musteriKopyasi) {
        await BelgePdfService.satisIrsaliyeMusteriYazdir(id);
      } else {
        await BelgePdfService.satisIrsaliyeDepoYazdir(id);
      }
    } catch (e) {
      if (!mounted) return;
      _mesaj(
        '${musteriKopyasi ? 'Müşteri' : 'Depo'} çıktısı hatası: $e',
        Colors.red,
      );
    }
  }

  Future<void> _pdfPaylas(Map<String, dynamic> irsaliye) async {
    final id = _int(irsaliye['irsaliye_id']);
    if (id <= 0) {
      _mesaj('Geçersiz satış irsaliyesi.', Colors.red);
      return;
    }
    try {
      await BelgePdfService.satisIrsaliyePaylas(id);
    } catch (e) {
      if (!mounted) return;
      _mesaj('PDF oluşturma hatası: $e', Colors.red);
    }
  }

  String _whatsAppTelefon(dynamic deger) {
    var no = deger?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';

    if (no.startsWith('00')) {
      no = no.substring(2);
    }

    if (no.startsWith('0') && no.length == 11) {
      no = '90${no.substring(1)}';
    } else if (no.length == 10 && no.startsWith('5')) {
      no = '90$no';
    }

    return no;
  }

  Future<void> _whatsAppIrsaliyeGonder(Map<String, dynamic> irsaliye) async {
    final id = _int(irsaliye['irsaliye_id']);

    if (id <= 0) {
      _mesaj('Geçersiz satış irsaliyesi.', Colors.red);
      return;
    }

    try {
      final cariId = irsaliye['cari_id'];

      final cariler = List<Map<String, dynamic>>.from(
        await SupabaseService.supabase
            .from('cariler')
            .select('cari_id, unvan, telefon')
            .eq('cari_id', cariId)
            .limit(1),
      );

      if (cariler.isEmpty) {
        throw Exception('Cari kartı bulunamadı.');
      }

      final cari = cariler.first;
      final telefon = _whatsAppTelefon(cari['telefon']);

      if (telefon.length < 10) {
        throw Exception('Cari kartındaki telefon numarası boş veya geçersiz.');
      }

      final unvan = _m(cari['unvan']);
      final irsaliyeNo = _m(irsaliye['irsaliye_no']);

      // Önce ürün kodu bulunmayan PDF oluşturulur, ardından hazır
      // mesajla müşterinin WhatsApp görüşmesi açılır.
      await BelgePdfService.satisIrsaliyePaylas(id);
      final firma = await FirmaAyarlariService.getir();

      final mesaj =
          'Sayın $unvan,\n\n'
          '$irsaliyeNo numaralı satış irsaliyeniz hazırlanmıştır.\n\n'
          'Aldığınız parçalara ait irsaliyeyi ekte bilgilerinize sunarız.\n'
          'Bizi tercih ettiğiniz için teşekkür eder, '
          'iyi günlerde kullanmanızı dileriz.\n\n'
          '${firma.unvan}';

      final uri = Uri.https('wa.me', '/$telefon', <String, String>{
        'text': mesaj,
      });

      final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!acildi) {
        throw Exception('WhatsApp açılamadı.');
      }

      if (!mounted) return;

      _mesaj(
        'PDF oluşturuldu. WhatsApp açıldı; PDF’yi görüşmeye '
        'ekleyip mesajı gönderin.',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      _mesaj('WhatsApp işlemi başlatılamadı: $e', Colors.red);
    }
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  Widget _bilgiKarti({
    required String baslik,
    required String deger,
    required IconData ikon,
    Color? renk,
  }) {
    final kartRengi = renk ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kartRengi.withOpacity(0.06),
        border: Border.all(color: kartRengi.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: MobilYatayRow(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: kartRengi.withOpacity(0.12),
            child: Icon(ikon, size: 18, color: kartRengi),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  deger,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detayKarti(Map<String, dynamic> detay) {
    final durumRengi = _durumRengi(detay['durum']);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MobilYatayRow(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _m(detay['urun_adi']),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          Text(
                  markaVeUreticiKodu(
                    detay['marka'],
                    detay['uretici_kodu'],
                  ),
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                          Text('OEM: ${_m(detay['oem_no'])}'),
                          Text('Marka: ${_m(detay['marka'])}'),
                          Text('RAF: ${_m(detay['raf'])}'),
                          Text(
                            'Mevcut Stok: ${_miktar(detay['stok_miktari'])}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: durumRengi.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _m(detay['durum']),
                    style: TextStyle(
                      color: durumRengi,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _kucukBilgi('Miktar', _miktar(detay['miktar'])),
                _kucukBilgi(
                  'Faturalanan',
                  _miktar(detay['faturalanan_miktar']),
                ),
                _kucukBilgi('Kalan', _miktar(detay['kalan_miktar'])),
                _kucukBilgi('Birim Fiyat', _para(detay['birim_fiyat'])),
                _kucukBilgi(
                  'İndirim',
                  '%${_s(detay['indirim_orani']).toStringAsFixed(2)}',
                ),
                _kucukBilgi(
                  'KDV',
                  '%${_s(detay['kdv_orani']).toStringAsFixed(0)}',
                ),
                _kucukBilgi(
                  'Satır Toplamı',
                  _para(_satirToplam(detay)),
                  vurgu: true,
                ),
              ],
            ),
            if (_m(detay['aciklama']) != '-')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Açıklama: '
                  '${_m(detay['aciklama'])}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kucukBilgi(String baslik, String deger, {bool vurgu = false}) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            deger,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: vurgu ? Colors.green.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _bagliSatisFaturaNolari(int irsaliyeId) async {
    final baglantilar = await SupabaseService.supabase
        .from('satis_irsaliye_fatura')
        .select('satis_id')
        .eq('irsaliye_id', irsaliyeId);

    final ids = List<Map<String, dynamic>>.from(baglantilar)
        .map((e) => int.tryParse(e['satis_id']?.toString() ?? ''))
        .whereType<int>()
        .toSet()
        .toList();

    if (ids.isEmpty) return [];

    final faturalar = await SupabaseService.supabase
        .from('satis_baslik')
        .select('satis_id, fatura_no')
        .inFilter('satis_id', ids)
        .order('tarih');

    return List<Map<String, dynamic>>.from(faturalar)
        .map((e) => e['fatura_no']?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool _topluSecilebilir(Map<String, dynamic> irsaliye) {
    final durum = _m(irsaliye['durum']).toUpperCase();

    return durum == 'ONAYLANDI';
  }

  void _irsaliyeSecimDegistir(Map<String, dynamic> irsaliye, bool? secili) {
    final id = _int(irsaliye['irsaliye_id']);

    if (id <= 0 || !_topluSecilebilir(irsaliye)) {
      return;
    }

    setState(() {
      if (secili == true) {
        _secilenIrsaliyeIds.add(id);
      } else {
        _secilenIrsaliyeIds.remove(id);
      }
    });
  }

  Future<void> _topluFaturala() async {
    if (_secilenIrsaliyeIds.isEmpty) {
      _mesaj('Toplu faturalama için en az bir irsaliye seçin.', Colors.orange);
      return;
    }

    final secilenler = _tum.where((irsaliye) {
      return _secilenIrsaliyeIds.contains(_int(irsaliye['irsaliye_id']));
    }).toList();

    if (secilenler.isEmpty) {
      _mesaj('Seçili irsaliyeler bulunamadı.', Colors.red);
      return;
    }

    final ilkCari = _int(secilenler.first['cari_id']);
    final ilkDepo = _int(secilenler.first['depo_id']);

    final uyumsuz = secilenler.any((irsaliye) {
      return _int(irsaliye['cari_id']) != ilkCari ||
          _int(irsaliye['depo_id']) != ilkDepo ||
          !_topluSecilebilir(irsaliye);
    });

    if (uyumsuz) {
      _mesaj(
        'Toplu faturalamada cari, depo aynı olmalı ve tüm irsaliyeler ONAYLANDI durumunda olmalıdır.',
        Colors.red,
      );
      return;
    }

    final detayResponse = await SupabaseService.supabase
        .from('satis_irsaliye_detay')
        .select()
        .inFilter('irsaliye_id', _secilenIrsaliyeIds.toList())
        .gt('kalan_miktar', 0)
        .order('irsaliye_id')
        .order('detay_id');

    final detaylar = List<Map<String, dynamic>>.from(detayResponse);

    if (detaylar.isEmpty) {
      _mesaj(
        'Seçilen irsaliyelerde faturalanacak kalan miktar yok.',
        Colors.orange,
      );
      return;
    }

    final faturaNoController = TextEditingController();

    final belgeNoController = TextEditingController();

    String odemeTipi = 'Veresiye';
    int? kasaId;

    try {
      faturaNoController.text = await SupabaseService.yeniBelgeNoGetir(
        belgeTipi: 'SATIŞ',
      );
    } catch (e) {
      debugPrint('PRO ERP sessiz hata [$e]');
    }

    if (!mounted) return;

    final sonuc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final veresiyeMi = odemeTipi == 'Veresiye';

            final toplamKalem = detaylar.length;

            final toplamMiktar = detaylar.fold<double>(
              0,
              (toplam, d) => toplam + _s(d['kalan_miktar']),
            );

            return AlertDialog(
              title: MobilYatayRow(
                children: [
                  const Icon(Icons.receipt_long_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Toplu Satiş Faturası - '
                      '${secilenler.length} İrsaliye',
                    ),
                  ),
                ],
              ),
              content: MobilDialogIcerik(
                width: 860,
                height: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 200,
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
                          width: 190,
                          child: DropdownButtonFormField<String>(
                            value: odemeTipi,
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
                              if (deger == null) {
                                return;
                              }

                              setDialogState(() {
                                odemeTipi = deger;

                                if (deger == 'Veresiye') {
                                  kasaId = null;
                                } else if (kasaId == null &&
                                    _kasalar.isNotEmpty) {
                                  kasaId = _int(_kasalar.first['kasa_id']);
                                }
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: DropdownButtonFormField<int>(
                            value: veresiyeMi ? null : kasaId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Kasa / Banka',
                              border: OutlineInputBorder(),
                            ),
                            items: _kasalar.map((kasa) {
                              final id = _int(kasa['kasa_id']);

                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(_m(kasa['kasa_adi'])),
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
                    Card(
                      elevation: 0,
                      color: Colors.blue.withOpacity(0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 28,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Cari: ${_cariAdi(ilkCari)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('Depo: ${_depoAdi(ilkDepo)}'),
                            Text('İrsaliye: ${secilenler.length}'),
                            Text('Kalem: $toplamKalem'),
                            Text(
                              'Toplam Miktar: '
                              '${_miktar(toplamMiktar)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Faturaya bağlanacak irsaliyeler',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.separated(
                        itemCount: secilenler.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final irsaliye = secilenler[index];

                          final irsDetay = detaylar.where(
                            (d) =>
                                _int(d['irsaliye_id']) ==
                                _int(irsaliye['irsaliye_id']),
                          );

                          final miktar = irsDetay.fold<double>(
                            0,
                            (toplam, d) => toplam + _s(d['kalan_miktar']),
                          );

                          return ListTile(
                            leading: const Icon(Icons.local_shipping_rounded),
                            title: Text(
                              _m(irsaliye['irsaliye_no']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(_tarih(irsaliye['tarih'])),
                            trailing: Text('${_miktar(miktar)} Adet'),
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
                    if (!veresiyeMi && kasaId == null) {
                      _mesaj('Peşin işlemde kasa seçin.', Colors.orange);
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'odeme_tipi': odemeTipi,
                      'kasa_id': veresiyeMi ? null : kasaId,
                    });
                  },
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Tek Fatura Oluştur'),
                ),
              ],
            );
          },
        );
      },
    );

    if (sonuc == null) {
      faturaNoController.dispose();

      belgeNoController.dispose();

      return;
    }

    setState(() {
      _islem = true;
    });

    try {
      final response = await SupabaseService.supabase.rpc(
        'satis_irsaliye_toplu_faturala',
        params: {
          'p_irsaliye_ids': _secilenIrsaliyeIds.toList(),
          'p_kasa_id': sonuc['kasa_id'],
          'p_odeme_tipi': sonuc['odeme_tipi'],
          'p_fatura_no': faturaNoController.text.trim(),

          'p_belge_no': belgeNoController.text.trim(),

          'p_fiyat_tipi': 'PERAKENDE',
          'p_kullanici': YetkiService.aktifKullanici,
        },
      );

      if (!mounted) return;

      _mesaj('Toplu fatura oluşturuldu. ID: $response', Colors.green);

      setState(() {
        _secilenIrsaliyeIds.clear();
      });

      await _yukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj('Toplu faturalama hatası: $e', Colors.red);
    } finally {
      faturaNoController.dispose();

      belgeNoController.dispose();

      if (mounted) {
        setState(() {
          _islem = false;
        });
      }
    }
  }

  Future<void> _goster(Map<String, dynamic> irsaliye) async {
    final irsaliyeId = _int(irsaliye['irsaliye_id']);
    if (irsaliyeId <= 0) return;

    List<Map<String, dynamic>> detaylar;

    try {
      detaylar = await _detay(irsaliyeId);
    } catch (e) {
      if (!mounted) return;
      _mesaj('İrsaliye detayları yüklenemedi: $e', Colors.red);
      return;
    }

    List<String> bagliFaturaNolari = [];

    try {
      bagliFaturaNolari = await _bagliSatisFaturaNolari(irsaliyeId);
    } catch (e) {
      debugPrint('Bağlı satış faturaları yüklenemedi: $e');
    }

    if (!mounted) return;

    final araToplam = detaylar.fold<double>(
      0,
      (toplam, detay) => toplam + _satirBrut(detay),
    );

    final indirimToplam = detaylar.fold<double>(
      0,
      (toplam, detay) => toplam + _satirIndirim(detay),
    );

    final kdvToplam = detaylar.fold<double>(
      0,
      (toplam, detay) => toplam + _satirKdv(detay),
    );

    final genelToplam = araToplam - indirimToplam + kdvToplam;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final durumRengi = _durumRengi(irsaliye['durum']);
        final mobil = MobilUyum.telefon(dialogContext);

        return AlertDialog(
          insetPadding: const EdgeInsets.all(18),
          title: MobilYatayRow(
            mobilDikey: true,
            children: [
              const Icon(Icons.local_shipping_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Satış İrsaliyesi: ${_m(irsaliye['irsaliye_no'])}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: durumRengi.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _m(irsaliye['durum']),
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
            width: 1040,
            height: 700,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      _ustBilgi('İrsaliye No', _m(irsaliye['irsaliye_no'])),
                      _ustBilgi(
                        'Bağlı Fatura',
                        bagliFaturaNolari.isEmpty
                            ? '-'
                            : bagliFaturaNolari.join(', '),
                      ),
                      _ustBilgi(
                        'Cari / Müşteri',
                        _cariAdi(irsaliye['cari_id']),
                      ),
                      _ustBilgi('Tarih', _tarih(irsaliye['tarih'])),
                      _ustBilgi('Durum', _m(irsaliye['durum'])),
                      _ustBilgi('Depo', _depoAdi(irsaliye['depo_id'])),
                      _ustBilgi('Sevk Tarihi', _tarih(irsaliye['sevk_tarihi'])),
                      _ustBilgi('Kullanıcı', _m(irsaliye['kullanici'])),
                      _ustBilgi('Açıklama', _m(irsaliye['aciklama'])),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: detaylar.isEmpty
                      ? const Center(child: Text('İrsaliye kalemi bulunamadı.'))
                      : mobil
                      ? ListView.separated(
                          itemCount: detaylar.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _detayKarti(detaylar[index]),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(10),
                                  ),
                                ),
                                child: const MobilYatayRow(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Ürün',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Marka / Kod',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'RAF',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Miktar',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Birim Fiyat',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'KDV %',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Tutar',
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: detaylar.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final detay = detaylar[index];

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 13,
                                      ),
                                      child: MobilYatayRow(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              _m(detay['urun_adi']),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
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
                                            child: Text(_m(detay['raf'])),
                                          ),
                                          Expanded(
                                            child: Text(
                                              _miktar(detay['miktar']),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _para(detay['birim_fiyat']),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              _s(detay['kdv_orani'])
                                                  .toStringAsFixed(0),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _para(_satirMatrah(detay)),
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
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
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _toplamKutusu('Ara Toplam', _para(araToplam)),
                      if (indirimToplam > 0)
                        _toplamKutusu('İndirim', _para(indirimToplam)),
                      _toplamKutusu('KDV', _para(kdvToplam)),
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
            if (_m(irsaliye['durum']).toUpperCase() == 'ONAYLANDI')
              ElevatedButton.icon(
                onPressed: _islem
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        await _faturala(irsaliye, detaylar);
                      },
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Faturala'),
              ),
            if (_m(irsaliye['durum']).toUpperCase() == 'HAZIRLANIYOR')
              OutlinedButton.icon(
                onPressed: _islem
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        await _duzeltAc(irsaliye);
                      },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Düzelt'),
              ),
            if (_m(irsaliye['durum']).toUpperCase() == 'HAZIRLANIYOR')
              ElevatedButton.icon(
                onPressed: _islem
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        await _onayla(irsaliye);
                      },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Onayla'),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                await _pdfPaylas(irsaliye);
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Müşteri PDF / Paylaş'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
              ),
              onPressed: () async {
                await _whatsAppIrsaliyeGonder(irsaliye);
              },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('WhatsApp Gönder'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await _yazdir(irsaliye, musteriKopyasi: false);
              },
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Depo Çıktısı'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await _yazdir(irsaliye, musteriKopyasi: true);
              },
              icon: const Icon(Icons.print_rounded),
              label: const Text('Müşteri Çıktısı'),
            ),
            if (_m(irsaliye['durum']).toUpperCase() == 'HAZIRLANIYOR')
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: _islem
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        await _iptal(irsaliye);
                      },
                icon: const Icon(Icons.cancel_rounded),
                label: const Text('İptal'),
              ),
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

  Widget _ustBilgi(String baslik, String deger) {
    return SizedBox(
      width: 190,
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _toplamKutusu(String baslik, String deger, {bool vurgu = false}) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: vurgu ? Colors.teal.withOpacity(0.10) : Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            baslik,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            deger,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: vurgu ? Colors.teal.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _irsaliyeKarti(Map<String, dynamic> irsaliye) {
    final durumRengi = _durumRengi(irsaliye['durum']);

    if (MobilUyum.telefon(context)) {
      return _mobilIrsaliyeKarti(irsaliye, durumRengi);
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _goster(irsaliye);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: MobilYatayRow(
            children: [
              if (_topluSecilebilir(irsaliye)) ...[
                Checkbox(
                  value: _secilenIrsaliyeIds.contains(
                    _int(irsaliye['irsaliye_id']),
                  ),
                  onChanged: (deger) {
                    _irsaliyeSecimDegistir(irsaliye, deger);
                  },
                ),
                const SizedBox(width: 4),
              ],
              CircleAvatar(
                radius: 24,
                backgroundColor: durumRengi.withOpacity(0.12),
                child: Icon(_durumIkonu(irsaliye['durum']), color: durumRengi),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _m(irsaliye['irsaliye_no']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (irsaliye['konsinye'] == true) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: const Text(
                          'KONSİNYE ÇIKIŞ',
                          style: TextStyle(
                            color: Colors.teal,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _tarih(irsaliye['tarih']),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cariAdi(irsaliye['cari_id']),
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
                        Text('Depo: ${_depoAdi(irsaliye['depo_id'])}'),
                        Text('Kullanıcı: ${_m(irsaliye['kullanici'])}'),
                        if (_m(irsaliye['aciklama']) != '-')
                          Text(
                            'Açıklama: ${_m(irsaliye['aciklama'])}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: durumRengi.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _m(irsaliye['durum']),
                  style: TextStyle(
                    color: durumRengi,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobilIrsaliyeKarti(Map<String, dynamic> irsaliye, Color durumRengi) {
    final secilebilir = _topluSecilebilir(irsaliye);
    final id = _int(irsaliye['irsaliye_id']);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _goster(irsaliye),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (secilebilir)
                    Checkbox(
                      value: _secilenIrsaliyeIds.contains(id),
                      onChanged: (deger) =>
                          _irsaliyeSecimDegistir(irsaliye, deger),
                      visualDensity: VisualDensity.compact,
                    ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: durumRengi.withOpacity(0.12),
                    child: Icon(
                      _durumIkonu(irsaliye['durum']),
                      color: durumRengi,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _m(irsaliye['irsaliye_no']),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _tarih(irsaliye['tarih']),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: durumRengi.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _m(irsaliye['durum']),
                      style: TextStyle(
                        color: durumRengi,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _cariAdi(irsaliye['cari_id']),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  Text('Depo: ${_depoAdi(irsaliye['depo_id'])}'),
                  Text('Kullanıcı: ${_m(irsaliye['kullanici'])}'),
                  if (irsaliye['konsinye'] == true)
                    const Text(
                      'KONSİNYE ÇIKIŞ',
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              if (_m(irsaliye['aciklama']) != '-') ...[
                const SizedBox(height: 6),
                Text(
                  'Açıklama: ${_m(irsaliye['aciklama'])}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtrePaneli(bool mobil) {
    final arama = TextField(
      controller: _aramaController,
      decoration: InputDecoration(
        hintText: 'İrsaliye no, cari, depo, durum, açıklama...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _aramaController.text.isEmpty
            ? null
            : IconButton(
                onPressed: _aramaController.clear,
                icon: const Icon(Icons.clear_rounded),
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    final durum = DropdownButtonFormField<String>(
      value: _durum,
      decoration: const InputDecoration(
        labelText: 'Durum',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'TÜMÜ', child: Text('Tüm Durumlar')),
        DropdownMenuItem(value: 'HAZIRLANIYOR', child: Text('Hazırlanıyor')),
        DropdownMenuItem(value: 'ONAYLANDI', child: Text('Onaylandı')),
        DropdownMenuItem(value: 'FATURALANDI', child: Text('Faturalandı')),
        DropdownMenuItem(value: 'IPTAL', child: Text('İptal')),
      ],
      onChanged: (deger) {
        if (deger == null) return;
        setState(() => _durum = deger);
        _filtrele();
      },
    );

    if (mobil) {
      return Column(children: [arama, const SizedBox(height: 10), durum]);
    }
    return Row(
      children: [
        Expanded(child: arama),
        const SizedBox(width: 12),
        SizedBox(width: 210, child: durum),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MobilUyum.telefon(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'SATIŞ İRSALİYELERİ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          MobilAppBarActions(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: _islem || _secilenIrsaliyeIds.isEmpty
                      ? null
                      : _topluFaturala,
                  icon: const Icon(Icons.library_add_check_rounded),
                  label: Text(
                    'Toplu Faturala '
                    '(${_secilenIrsaliyeIds.length})',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: _islem ? null : _konsinyeIrsaliyeAc,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Konsinye Çıkış'),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: _islem ? null : _yeniIrsaliyeAc,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Yeni Satış İrsaliyesi'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Yenile',
                onPressed: _yukleniyor ? null : _yukle,
                icon: const Icon(Icons.refresh_rounded),
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
            child: _filtrePaneli(mobil),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _gorunen.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 72,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Satış irsaliyesi bulunamadı.',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _yukle,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _gorunen.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _irsaliyeKarti(_gorunen[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: mobil
          ? FloatingActionButton.extended(
              onPressed: _islem ? null : _yeniIrsaliyeAc,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni İrsaliye'),
            )
          : null,
    );
  }
}
