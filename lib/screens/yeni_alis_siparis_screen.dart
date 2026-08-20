// lib/screens/yeni_alis_siparis_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/belge_alt_toplam_cubugu.dart';
import '../widgets/belge_stok_arama_karti.dart';
import '../widgets/logo_klasik_belge_satiri.dart';

import '../models/stok_model.dart';
import '../services/supabase_service.dart';
import '../services/yetki_service.dart';

class YeniAlisSiparisScreen extends StatefulWidget {
  final bool kayitSonrasiKapat;

  const YeniAlisSiparisScreen({
    super.key,
    this.kayitSonrasiKapat = false,
  });

  @override
  State<YeniAlisSiparisScreen> createState() =>
      _YeniAlisSiparisScreenState();
}

class _YeniAlisSiparisScreenState
    extends State<YeniAlisSiparisScreen> {
  final TextEditingController _aramaController =
      TextEditingController();
  final TextEditingController _siparisNoController =
      TextEditingController();
  final TextEditingController _aciklamaController =
      TextEditingController();

  Timer? _aramaTimer;

  bool _yukleniyor = true;
  bool _araniyor = false;
  bool _kaydediliyor = false;

  int? _cariId;
  int? _depoId;

  String _odemeTipi = 'Veresiye';

  DateTime? _terminTarihi;

  List<Map<String, dynamic>> _cariler = [];
  List<Map<String, dynamic>> _depolar = [];
  List<StokModel> _urunler = [];

  final List<Map<String, dynamic>> _sepet = [];

  @override
  void initState() {
    super.initState();
    _ilkVerileriYukle();
    _yeniSiparisNoGetir();
  }

  @override
  void dispose() {
    _aramaTimer?.cancel();
    _aramaController.dispose();
    _siparisNoController.dispose();
    _aciklamaController.dispose();
    super.dispose();
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

  Future<void> _ilkVerileriYukle() async {
    if (!mounted) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      final sonuclar = await Future.wait([
        SupabaseService.getCariler(),
        SupabaseService.supabase
            .from('depolar')
            .select('depo_id, depo_adi')
            .order('depo_adi'),
      ]);

      final cariler =
          List<Map<String, dynamic>>.from(sonuclar[0] as List);

      final depolar =
          List<Map<String, dynamic>>.from(sonuclar[1] as List);

      int? varsayilanCari;

      for (final cari in cariler) {
        final tip =
            cari['cari_tipi']?.toString().toUpperCase() ?? '';

        if (tip.contains('TEDARIKCI') ||
            tip.contains('TEDARİKÇİ') ||
            tip.contains('SATICI')) {
          varsayilanCari =
              int.tryParse(cari['cari_id'].toString());
          break;
        }
      }

      varsayilanCari ??= cariler.isEmpty
          ? null
          : int.tryParse(
              cariler.first['cari_id'].toString(),
            );

      if (!mounted) return;

      setState(() {
        _cariler = cariler;
        _depolar = depolar;

        _cariId = varsayilanCari;

        _depoId = depolar.isEmpty
            ? null
            : int.tryParse(
                depolar.first['depo_id'].toString(),
              );

        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      _mesaj(
        'Alış siparişi ekranı verileri yüklenemedi: $e',
        Colors.red,
      );
    }
  }

  Future<void> _yeniSiparisNoGetir() async {
    try {
      final response = await SupabaseService.supabase.rpc(
        'yeni_alis_siparis_no',
      );

      if (!mounted) return;

      _siparisNoController.text =
          response?.toString().trim() ?? '';
    } catch (e) {
      if (!mounted) return;

      _mesaj(
        'Alış sipariş numarası alınamadı: $e',
        Colors.red,
      );
    }
  }

  void _aramaYap(String deger) {
    _aramaTimer?.cancel();

    _aramaTimer = Timer(
      const Duration(milliseconds: 300),
      () async {
        final arama = deger.trim();

        if (arama.isEmpty) {
          if (!mounted) return;

          setState(() {
            _urunler = [];
          });

          return;
        }

        if (!mounted) return;

        setState(() {
          _araniyor = true;
        });

        try {
          final sonuc =
              await SupabaseService.stoklariGetir(
            aramaMetni: arama,
          );

          if (!mounted) return;

          setState(() {
            _urunler = sonuc;
            _araniyor = false;
          });
        } catch (e) {
          if (!mounted) return;

          setState(() {
            _araniyor = false;
          });

          _mesaj(
            'Ürün arama hatası: $e',
            Colors.red,
          );
        }
      },
    );
  }

  void _sepeteEkle(StokModel stok) {
    final index = _sepet.indexWhere(
      (item) => item['stok_id'] == stok.stokId,
    );

    setState(() {
      if (index >= 0) {
        final miktar = int.tryParse(
              _sepet[index]['miktar'].toString(),
            ) ??
            1;

        _sepet[index]['miktar'] = miktar + 1;
      } else {
        _sepet.add({
          'stok': stok,
          'stok_id': stok.stokId,
          'miktar': 1,
          'birim_fiyat': stok.alisFiyati,
          'indirim': 0.0,
          'kdv_orani': stok.kdv.round(),
          'aciklama': '',
        });
      }

      _aramaController.clear();
      _urunler = [];
    });
  }

  Future<void> _satirDuzenle(int index) async {
    final item = _sepet[index];
    final stok = item['stok'] as StokModel;

    final miktarController = TextEditingController(
      text: item['miktar'].toString(),
    );

    final fiyatController = TextEditingController(
      text: _sayi(
        item['birim_fiyat'],
      ).toStringAsFixed(2),
    );

    final indirimController = TextEditingController(
      text: _sayi(
        item['indirim'],
      ).toStringAsFixed(2),
    );

    final aciklamaController = TextEditingController(
      text: item['aciklama']?.toString() ?? '',
    );

    int kdv = int.tryParse(
          item['kdv_orani'].toString(),
        ) ??
        20;

    final sonuc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(stok.urunAdi),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mevcut stok: '
                        '${stok.stokMiktari.toStringAsFixed(0)}',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: miktarController,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText: 'Sipariş Miktarı',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: fiyatController,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Birim Alış Fiyatı',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller:
                            indirimController,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText: 'İndirim %',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                            isExpanded: true,
                        value: [0, 1, 10, 20]
                                .contains(kdv)
                            ? kdv
                            : 20,
                        decoration:
                            const InputDecoration(
                          labelText: 'KDV',
                          border:
                              OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 0,
                            child: Text('%0'),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Text('%1'),
                          ),
                          DropdownMenuItem(
                            value: 10,
                            child: Text('%10'),
                          ),
                          DropdownMenuItem(
                            value: 20,
                            child: Text('%20'),
                          ),
                        ],
                        onChanged: (deger) {
                          if (deger == null) return;

                          setDialogState(() {
                            kdv = deger;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller:
                            aciklamaController,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Satır Açıklaması',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      {
                        'miktar': _sayi(
                          miktarController.text,
                        ),
                        'birim_fiyat': _sayi(
                          fiyatController.text,
                        ),
                        'indirim': _sayi(
                          indirimController.text,
                        ),
                        'kdv_orani': kdv,
                        'aciklama':
                            aciklamaController.text
                                .trim(),
                      },
                    );
                  },
                  child: const Text('Uygula'),
                ),
              ],
            );
          },
        );
      },
    );

    miktarController.dispose();
    fiyatController.dispose();
    indirimController.dispose();
    aciklamaController.dispose();

    if (sonuc == null) return;

    final miktar =
        _sayi(sonuc['miktar']);
    final fiyat =
        _sayi(sonuc['birim_fiyat']);
    final indirim =
        _sayi(sonuc['indirim']);

    if (miktar <= 0) {
      _mesaj(
        'Sipariş miktarı sıfırdan büyük olmalıdır.',
        Colors.orange,
      );
      return;
    }

    if (fiyat < 0) {
      _mesaj(
        'Birim alış fiyatı negatif olamaz.',
        Colors.orange,
      );
      return;
    }

    if (indirim < 0 || indirim > 100) {
      _mesaj(
        'İndirim oranı 0 ile 100 arasında olmalıdır.',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _sepet[index].addAll(sonuc);
    });
  }

  double _satirBrut(
    Map<String, dynamic> item,
  ) {
    return _sayi(item['miktar']) *
        _sayi(item['birim_fiyat']);
  }

  double _satirIndirim(
    Map<String, dynamic> item,
  ) {
    return _satirBrut(item) *
        _sayi(item['indirim']) /
        100;
  }

  double _satirMatrah(
    Map<String, dynamic> item,
  ) {
    return _satirBrut(item) -
        _satirIndirim(item);
  }

  double _satirKdv(
    Map<String, dynamic> item,
  ) {
    return _satirMatrah(item) *
        _sayi(item['kdv_orani']) /
        100;
  }

  double _satirToplam(
    Map<String, dynamic> item,
  ) {
    return _satirMatrah(item) +
        _satirKdv(item);
  }

  double get _araToplam {
    return _sepet.fold<double>(
      0,
      (toplam, item) =>
          toplam + _satirBrut(item),
    );
  }

  double get _toplamIndirim {
    return _sepet.fold<double>(
      0,
      (toplam, item) =>
          toplam + _satirIndirim(item),
    );
  }

  double get _toplamKdv {
    return _sepet.fold<double>(
      0,
      (toplam, item) =>
          toplam + _satirKdv(item),
    );
  }

  double get _genelToplam {
    return _araToplam -
        _toplamIndirim +
        _toplamKdv;
  }

  Future<void> _terminTarihiSec() async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: _terminTarihi ??
          DateTime.now().add(
            const Duration(days: 1),
          ),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (secilen == null) return;

    setState(() {
      _terminTarihi = secilen;
    });
  }

  String _kisaTarih(DateTime? tarih) {
    if (tarih == null) {
      return 'Termin Tarihi';
    }

    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year}';
  }

  Future<void> _siparisiKaydet() async {
    if (_kaydediliyor) return;

    if (_cariId == null) {
      _mesaj(
        'Tedarikçi seçmelisiniz.',
        Colors.orange,
      );
      return;
    }

    if (_depoId == null) {
      _mesaj(
        'Depo seçmelisiniz.',
        Colors.orange,
      );
      return;
    }

    if (_sepet.isEmpty) {
      _mesaj(
        'Alış siparişine ürün eklemelisiniz.',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _kaydediliyor = true;
    });

    try {
      final detaylar = _sepet.map((item) {
        return <String, dynamic>{
          'stok_id': item['stok_id'],
          'miktar': _sayi(
            item['miktar'],
          ),
          'birim_fiyat': _sayi(
            item['birim_fiyat'],
          ),
          'indirim': _sayi(
            item['indirim'],
          ),
          'kdv_orani': int.tryParse(
                item['kdv_orani'].toString(),
              ) ??
              0,
          'aciklama':
              item['aciklama']?.toString() ??
                  '',
        };
      }).toList();

      final response =
          await SupabaseService.supabase.rpc(
        'alis_siparis_olustur',
        params: {
          'p_siparis_no':
              _siparisNoController.text.trim(),
          'p_cari_id': _cariId,
          'p_depo_id': _depoId,
          'p_odeme_tipi': _odemeTipi,
          'p_termin_tarihi':
              _terminTarihi
                  ?.toIso8601String()
                  .split('T')
                  .first,
          'p_aciklama':
              _aciklamaController.text.trim(),
          'p_kullanici': YetkiService.aktifKullanici,
          'p_detaylar': detaylar,
        },
      );

      final siparisId = int.tryParse(
        response?.toString() ?? '',
      );

      if (siparisId == null) {
        throw Exception(
          'Alış siparişi fonksiyonu geçerli bir ID döndürmedi.',
        );
      }

      if (!mounted) return;

      _mesaj(
        'Alış siparişi başarıyla kaydedildi. '
        'Sipariş ID: $siparisId',
        Colors.green,
      );

      if (widget.kayitSonrasiKapat) {
        Navigator.pop(context, true);
        return;
      }

      setState(() {
        _sepet.clear();
        _aramaController.clear();
        _aciklamaController.clear();
        _terminTarihi = null;
        _odemeTipi = 'Veresiye';
      });

      await _yeniSiparisNoGetir();
    } catch (e) {
      if (!mounted) return;

      _mesaj(
        'Alış siparişi kayıt hatası: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _kaydediliyor = false;
        });
      }
    }
  }

  void _mesaj(
    String mesaj,
    Color renk,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: renk,
      ),
    );
  }

  Widget _ustBilgiler() {
    return Card(
      margin:
          const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment:
              WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child:
                  DropdownButtonFormField<int>(
                            isExpanded: true,
                value: _cariId,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Tedarikçi / Cari',
                  border:
                      OutlineInputBorder(),
                ),
                items: _cariler.map((cari) {
                  return DropdownMenuItem<int>(
                    value: int.tryParse(
                      cari['cari_id']
                          .toString(),
                    ),
                    child: Text(
                      cari['unvan']
                              ?.toString() ??
                          '',
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (deger) {
                  setState(() {
                    _cariId = deger;
                  });
                },
              ),
            ),
            SizedBox(
              width: 180,
              child:
                  DropdownButtonFormField<int>(
                            isExpanded: true,
                value: _depoId,
                decoration:
                    const InputDecoration(
                  labelText: 'Depo',
                  border:
                      OutlineInputBorder(),
                ),
                items: _depolar.map((depo) {
                  return DropdownMenuItem<int>(
                    value: int.tryParse(
                      depo['depo_id']
                          .toString(),
                    ),
                    child: Text(
                      depo['depo_adi']
                              ?.toString() ??
                          '',
                    ),
                  );
                }).toList(),
                onChanged: (deger) {
                  setState(() {
                    _depoId = deger;
                  });
                },
              ),
            ),
            SizedBox(
              width: 170,
              child:
                  DropdownButtonFormField<String>(
                            isExpanded: true,
                value: _odemeTipi,
                decoration:
                    const InputDecoration(
                  labelText: 'Ödeme Tipi',
                  border:
                      OutlineInputBorder(),
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
                    child: Text(
                      'Kredi Kartı',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Havale',
                    child: Text(
                      'Havale / EFT',
                    ),
                  ),
                ],
                onChanged: (deger) {
                  if (deger == null) return;

                  setState(() {
                    _odemeTipi = deger;
                  });
                },
              ),
            ),
            SizedBox(
              width: 210,
              child: TextField(
                controller:
                    _siparisNoController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Alış Sipariş No',
                  border:
                      OutlineInputBorder(),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _terminTarihiSec,
              icon: const Icon(Icons.event),
              label: Text(
                _kisaTarih(_terminTarihi),
              ),
            ),
            SizedBox(
              width: 350,
              child: TextField(
                controller:
                    _aciklamaController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Sipariş Açıklaması',
                  border:
                      OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aramaPaneli() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            TextField(
              controller: _aramaController,
              decoration:
                  const InputDecoration(
                hintText:
                    'Ürün adı, üretici kodu, OEM, barkod, marka, RAF...',
                prefixIcon:
                    Icon(Icons.search),
                border:
                    OutlineInputBorder(),
              ),
              onChanged: _aramaYap,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _araniyor
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : _urunler.isEmpty
                      ? const Center(
                          child: Text(
                            'Ürün aramak için yazın.',
                            style: TextStyle(
                              color:
                                  Colors.grey,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount:
                              _urunler.length,
                          separatorBuilder:
                              (_, __) {
                            return const SizedBox(
                              height: 4,
                            );
                          },
                          itemBuilder:
                              (context, index) {
                            final stok =
                                _urunler[index];

                            return BelgeStokAramaKarti(
                              stok: stok,
                              onEkle: () => _sepeteEkle(stok),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sepetPaneli() {
    if (_sepet.isEmpty) {
      return const Card(
        margin: EdgeInsets.all(4),
        elevation: 0,
        child: Center(
          child: Text(
            'Alış siparişi sepeti boş.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    final depoAdi = _depolar
        .where((d) => int.tryParse('${d['depo_id'] ?? ''}') == _depoId)
        .map((d) => d['depo_adi']?.toString() ?? '-')
        .fold<String>('-', (onceki, deger) => deger);

    return Card(
      margin: const EdgeInsets.all(4),
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: LogoKlasikBelgeListe(
        alis: true,
        itemCount: _sepet.length,
        itemBuilder: (context, index) {
          final item = _sepet[index];
          final stok = item['stok'] as StokModel;
          final miktar = _sayi(item['miktar']);
          final fiyat = _sayi(item['birim_fiyat']);
          final indirim = _sayi(item['indirim']);
          final kdv = _sayi(item['kdv_orani']);

          return LogoKlasikBelgeSatiri(
            no: index + 1,
            kod: stok.ureticiKodu,
            aciklama: stok.urunAdi,
            miktar: miktar.toStringAsFixed(0),
            birim: 'Adet',
            fiyat: _para(fiyat),
            indirim: '%${indirim.toStringAsFixed(1)}',
            kdv: '%${kdv.toStringAsFixed(0)}',
            tutar: _para(_satirToplam(item)),
            raf: stok.raf.trim().isEmpty ? '-' : stok.raf.trim(),
            stok: stok.stokMiktari.toStringAsFixed(0),
            ambar: depoAdi,
            onEdit: () => _satirDuzenle(index),
          onDelete: () {
            setState(() => _sepet.removeAt(index));
          },
          );
        },
      ),
    );
  }

  Widget _altBolum() {
    return BelgeAltToplamCubugu(
      araToplam: _araToplam,
      iskontoToplam: _toplamIndirim,
      kdvToplam: _toplamKdv,
      genelToplam: _genelToplam,
      actions: [
        ElevatedButton.icon(
          onPressed: _kaydediliyor ? null : _siparisiKaydet,
          icon: _kaydediliyor
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(
            _kaydediliyor ? 'Kaydediliyor...' : 'Alış Siparişini Kaydet',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'YENİ ALIŞ SİPARİŞİ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _kaydediliyor
                ? null
                : _ilkVerileriYukle,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _yukleniyor
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : Column(
              children: [
                _ustBilgiler(),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 400,
                        child:
                            _aramaPaneli(),
                      ),
                      Expanded(
                        child:
                            _sepetPaneli(),
                      ),
                    ],
                  ),
                ),
                _altBolum(),
              ],
            ),
    );
  }
}
