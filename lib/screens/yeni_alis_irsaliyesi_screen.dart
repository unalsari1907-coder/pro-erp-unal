// lib/screens/yeni_alis_irsaliyesi_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/belge_stok_arama_karti.dart';
import '../widgets/logo_klasik_belge_satiri.dart';
import '../utils/marka_kod.dart';

import '../models/stok_model.dart';
import '../services/supabase_service.dart';
import '../services/yetki_service.dart';
import '../widgets/fiyat_seridi.dart';
import '../widgets/cari_sec_dialog.dart';
import '../widgets/mobil_uyum.dart';
import 'stok_sayfasi.dart';

class YeniAlisIrsaliyesiScreen extends StatefulWidget {
  final bool kayitSonrasiKapat;
  final bool konsinye;
  final Map<String, dynamic>? duzenlenecekIrsaliye;

  const YeniAlisIrsaliyesiScreen({
    super.key,
    this.kayitSonrasiKapat = false,
    this.konsinye = false,
    this.duzenlenecekIrsaliye,
  });

  @override
  State<YeniAlisIrsaliyesiScreen> createState() =>
      _YeniAlisIrsaliyesiScreenState();
}

class _YeniAlisIrsaliyesiScreenState extends State<YeniAlisIrsaliyesiScreen> {
  final TextEditingController _aramaController = TextEditingController();
  final TextEditingController _noController = TextEditingController();
  final TextEditingController _aciklamaController = TextEditingController();

  Timer? _aramaTimer;

  bool _yukleniyor = true;
  bool _araniyor = false;
  bool _kaydediliyor = false;

  int? _cariId;
  int? _depoId;

  List<Map<String, dynamic>> _cariler = [];
  List<Map<String, dynamic>> _depolar = [];
  List<StokModel> _urunler = [];

  final List<Map<String, dynamic>> _sepet = [];

  bool get _duzenlemeMi => widget.duzenlenecekIrsaliye != null;

  int get _duzenlenecekIrsaliyeId {
    return int.tryParse(
          widget.duzenlenecekIrsaliye?['irsaliye_id']?.toString() ?? '',
        ) ??
        0;
  }

  @override
  void initState() {
    super.initState();
    _baslangicYukle();
  }

  Future<void> _baslangicYukle() async {
    await _verileriYukle();

    if (!mounted) return;

    if (_duzenlemeMi) {
      await _duzenlenecekIrsaliyeyiYukle();
    } else {
      await _yeniNoGetir();
    }
  }

  @override
  void dispose() {
    _aramaTimer?.cancel();
    _aramaController.dispose();
    _noController.dispose();
    _aciklamaController.dispose();
    super.dispose();
  }

  double _sayi(dynamic deger) {
    return double.tryParse(deger?.toString().replaceAll(',', '.') ?? '0') ??
        0.0;
  }

  String _para(dynamic deger) {
    return '${_sayi(deger).toStringAsFixed(2)} ₺';
  }

  int? _varsayilanMerkezDepoId(List<Map<String, dynamic>> depolar) {
    if (depolar.isEmpty) return null;
    for (final depo in depolar) {
      final ad = depo['depo_adi']?.toString().trim().toUpperCase() ?? '';
      if (ad.contains('MERKEZ')) {
        return int.tryParse(depo['depo_id']?.toString() ?? '');
      }
    }
    return int.tryParse(depolar.first['depo_id']?.toString() ?? '');
  }

  String _listeMetni(List<String> liste) {
    final temiz = liste.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return temiz.isEmpty ? '-' : temiz.join(', ');
  }

  Future<void> _stokEkraniniAc(StokModel stok) async {
    final arama = stok.ureticiKodu.trim().isNotEmpty
        ? stok.ureticiKodu.trim()
        : stok.urunAdi.trim();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StokSayfasi(acilisArama: arama),
      ),
    );
  }

  Future<void> _stokDetayAc(StokModel stok) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(stok.urunAdi),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _detaySatiri('Üretici Kodu', stok.ureticiKodu),
                _detaySatiri('OEM', _listeMetni(stok.oemler)),
                _detaySatiri('CROSS', _listeMetni(stok.crossKodlar)),
                _detaySatiri('Rakip Kod', _listeMetni(stok.rakipKodlar)),
                _detaySatiri('RAF', stok.raf),
                _detaySatiri('Mevcut Stok', stok.stokMiktari.toStringAsFixed(0)),
                _detaySatiri('Marka', stok.marka),
                _detaySatiri('Araç', _listeMetni(stok.araclar)),
                _detaySatiri('Ürün Özelliği', stok.urunOzellik),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _detaySatiri(String baslik, String deger) {
    final metin = deger.trim().isEmpty ? '-' : deger.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 125,
            child: Text(
              baslik,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(metin)),
        ],
      ),
    );
  }

  Widget _stokRafRozeti(StokModel stok) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: stok.stokMiktari > 0 ? Colors.green.shade50 : Colors.red.shade50,
            border: Border.all(
              color: stok.stokMiktari > 0 ? Colors.green.shade300 : Colors.red.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'STOK ${stok.stokMiktari.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: stok.stokMiktari > 0 ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            border: Border.all(color: Colors.blueGrey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'RAF ${stok.raf.trim().isEmpty ? '-' : stok.raf.trim()}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.blueGrey.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _kurumsalBelgeBasligi(String belgeTipi) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded, color: Colors.blue.shade800),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ÜNAL YEDEK PARÇA',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text('Kurumsal ERP • Belge Oluşturma'),
              ],
            ),
          ),
          Text(
            belgeTipi,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verileriYukle() async {
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

      final cariler = List<Map<String, dynamic>>.from(sonuclar[0] as List);
      final depolar = List<Map<String, dynamic>>.from(sonuclar[1] as List);

      if (!mounted) return;

      setState(() {
        _cariler = cariler;
        _depolar = depolar;

        _cariId = cariler.isEmpty
            ? null
            : int.tryParse(cariler.first['cari_id'].toString());

        _depoId = _varsayilanMerkezDepoId(depolar);

        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      _mesaj('Veriler yüklenemedi: $e', Colors.red);
    }
  }

  Future<void> _duzenlenecekIrsaliyeyiYukle() async {
    final irsaliye = widget.duzenlenecekIrsaliye;
    final irsaliyeId = _duzenlenecekIrsaliyeId;

    if (irsaliye == null || irsaliyeId <= 0) {
      _mesaj('Düzenlenecek alış irsaliyesi bulunamadı.', Colors.red);
      return;
    }

    final durum = irsaliye['durum']?.toString().toUpperCase() ?? '';

    if (durum != 'HAZIRLANIYOR') {
      _mesaj(
        'Sadece HAZIRLANIYOR durumundaki irsaliye düzeltilebilir.',
        Colors.orange,
      );

      if (mounted) {
        Navigator.pop(context, false);
      }
      return;
    }

    setState(() {
      _yukleniyor = true;
    });

    try {
      final detayResponse = await SupabaseService.supabase
          .from('alis_irsaliye_detay')
          .select()
          .eq('irsaliye_id', irsaliyeId)
          .order('detay_id');

      final detaylar = List<Map<String, dynamic>>.from(detayResponse);

      final stokIds = detaylar
          .map((detay) => int.tryParse(detay['stok_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet()
          .toList();

      final stokHaritasi = <int, StokModel>{};

      if (stokIds.isNotEmpty) {
        final stokResponse = await SupabaseService.supabase
            .from('stoklar')
            .select()
            .inFilter('stok_id', stokIds);

        for (final json in List<Map<String, dynamic>>.from(stokResponse)) {
          final stok = StokModel.fromJson(json);
          stokHaritasi[stok.stokId] = stok;
        }
      }

      final yeniSepet = <Map<String, dynamic>>[];

      for (final detay in detaylar) {
        final stokId = int.tryParse(detay['stok_id']?.toString() ?? '') ?? 0;

        final stok = stokHaritasi[stokId];

        if (stok == null) continue;

        yeniSepet.add({
          'stok': stok,
          'stok_id': stok.stokId,
          'miktar': _sayi(detay['miktar']),
          'fiyat_tipi': 'AFN',
          'birim_fiyat': _sayi(detay['birim_fiyat']),
          'indirim': _sayi(detay['indirim_orani']),
          'kdv_orani':
              int.tryParse(
                detay['kdv_orani']?.toString().split('.').first ?? '',
              ) ??
              stok.kdv.round(),
          'aciklama': detay['aciklama']?.toString() ?? '',
        });
      }

      if (!mounted) return;

      setState(() {
        _cariId = int.tryParse(irsaliye['cari_id']?.toString() ?? '');
        _depoId = int.tryParse(irsaliye['depo_id']?.toString() ?? '');
        _noController.text = irsaliye['irsaliye_no']?.toString() ?? '';
        _aciklamaController.text = irsaliye['aciklama']?.toString() ?? '';

        _sepet
          ..clear()
          ..addAll(yeniSepet);

        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      _mesaj('İrsaliye düzenleme verileri yüklenemedi: $e', Colors.red);
    }
  }

  Future<void> _yeniNoGetir() async {
    try {
      final sonuc = await SupabaseService.supabase.rpc('yeni_alis_irsaliye_no');

      if (!mounted) return;

      _noController.text = sonuc?.toString().trim() ?? '';
    } catch (e) {
      if (!mounted) return;

      _mesaj('İrsaliye numarası alınamadı: $e', Colors.red);
    }
  }

  void _aramaYap(String arama) {
    _aramaTimer?.cancel();

    _aramaTimer = Timer(const Duration(milliseconds: 300), () async {
      final metin = arama.trim();

      if (metin.isEmpty) {
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
        final sonuc = await SupabaseService.stoklariGetir(aramaMetni: metin);

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

        _mesaj('Ürün arama hatası: $e', Colors.red);
      }
    });
  }

  void _sepeteEkle(StokModel stok) {
    final index = _sepet.indexWhere((item) => item['stok_id'] == stok.stokId);

    setState(() {
      if (index >= 0) {
        _sepet[index]['miktar'] = _sayi(_sepet[index]['miktar']) + 1;
      } else {
        _sepet.add({
          'stok': stok,
          'stok_id': stok.stokId,
          'miktar': 1.0,
          'fiyat_tipi': 'AFN',
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

  Future<void> _alisFiyatiDegistir(int index) async {
    final item = _sepet[index];

    final controller = TextEditingController(
      text: _sayi(item['birim_fiyat']).toStringAsFixed(2),
    );

    final sonuc = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('AFN / Alış Fiyatını Değiştir'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Birim Alış Fiyatı',
              suffixText: '₺',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              Navigator.pop(
                dialogContext,
                double.tryParse(controller.text.replaceAll(',', '.')) ?? 0,
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  double.tryParse(controller.text.replaceAll(',', '.')) ?? 0,
                );
              },
              child: const Text('Uygula'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (sonuc == null) return;

    if (sonuc < 0) {
      _mesaj('Alış fiyatı negatif olamaz.', Colors.orange);
      return;
    }

    setState(() {
      _sepet[index]['fiyat_tipi'] = 'AFN';
      _sepet[index]['birim_fiyat'] = sonuc;
    });
  }

  Future<void> _kaydet() async {
    if (_kaydediliyor) return;

    if (_cariId == null || _depoId == null || _sepet.isEmpty) {
      _mesaj('Tedarikçi, depo ve ürün seçmelisiniz.', Colors.orange);
      return;
    }

    setState(() {
      _kaydediliyor = true;
    });

    try {
      final detaylar = _sepet.map((item) {
        return <String, dynamic>{
          'stok_id': item['stok_id'],
          'miktar': _sayi(item['miktar']),
          'birim_fiyat': _sayi(item['birim_fiyat']),
          'indirim': _sayi(item['indirim']),
          'kdv_orani': int.tryParse(item['kdv_orani'].toString()) ?? 0,
          'aciklama': item['aciklama']?.toString() ?? '',
        };
      }).toList();

      final sonuc = await SupabaseService.supabase.rpc(
        _duzenlemeMi ? 'alis_irsaliye_guncelle' : 'alis_irsaliye_olustur',
        params: _duzenlemeMi
            ? {
                'p_irsaliye_id': _duzenlenecekIrsaliyeId,
                'p_irsaliye_no': _noController.text.trim(),
                'p_cari_id': _cariId,
                'p_depo_id': _depoId,
                'p_aciklama': _aciklamaController.text.trim(),
                'p_kullanici': YetkiService.aktifKullanici,
                'p_detaylar': detaylar,
              }
            : {
                'p_irsaliye_no': _noController.text.trim(),
                'p_cari_id': _cariId,
                'p_depo_id': _depoId,
                'p_siparis_id': null,
                'p_aciklama': _aciklamaController.text.trim(),
                'p_kullanici': YetkiService.aktifKullanici,
                'p_detaylar': detaylar,
              },
      );

      if (!_duzenlemeMi && widget.konsinye) {
        final yeniId = int.tryParse(sonuc?.toString() ?? '');

        if (yeniId != null) {
          await SupabaseService.supabase
              .from('alis_irsaliye_baslik')
              .update({'konsinye': true})
              .eq('irsaliye_id', yeniId);
        }
      }

      if (!mounted) return;

      _mesaj(
        _duzenlemeMi
            ? 'Alış irsaliyesi güncellendi.'
            : 'Alış irsaliyesi oluşturuldu: $sonuc',
        Colors.green,
      );

      if (_duzenlemeMi || widget.kayitSonrasiKapat) {
        Navigator.pop(context, true);
        return;
      }

      setState(() {
        _sepet.clear();
        _aramaController.clear();
        _aciklamaController.clear();
      });

      await _yeniNoGetir();
    } catch (e) {
      if (!mounted) return;

      _mesaj('Kayıt hatası: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _kaydediliyor = false;
        });
      }
    }
  }

  void _sepetiTemizle() {
    setState(() {
      _sepet.clear();
    });
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  double get _araToplam {
    return _sepet.fold<double>(
      0,
      (toplam, item) =>
          toplam + (_sayi(item['miktar']) * _sayi(item['birim_fiyat'])),
    );
  }

  double get _iskontoToplam {
    return _sepet.fold<double>(0, (toplam, item) {
      final brut = _sayi(item['miktar']) * _sayi(item['birim_fiyat']);

      return toplam + brut * _sayi(item['indirim']) / 100;
    });
  }

  double get _kdvToplam {
    return _sepet.fold<double>(0, (toplam, item) {
      final brut = _sayi(item['miktar']) * _sayi(item['birim_fiyat']);

      final iskonto = brut * _sayi(item['indirim']) / 100;

      final matrah = brut - iskonto;

      return toplam + matrah * _sayi(item['kdv_orani']) / 100;
    });
  }

  double get _genelToplam {
    return _araToplam - _iskontoToplam + _kdvToplam;
  }

  Widget _fiyatKutusu(String kod, double fiyat, Color renk) {
    return Expanded(
      child: Column(
        children: [
          Text(
            kod,
            style: TextStyle(
              color: renk,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _para(fiyat),
            style: TextStyle(
              color: renk,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _urunKarti(StokModel stok) {
    return BelgeStokAramaKarti(
      stok: stok,
      onEkle: () => _sepeteEkle(stok),
    );
  }

  void _miktarArtir(int index) {
    final item = _sepet[index];
    final mevcut = _sayi(item['miktar']);

    setState(() {
      _sepet[index]['miktar'] = mevcut + 1;
    });
  }

  void _miktarAzalt(int index) {
    final mevcut = _sayi(_sepet[index]['miktar']);

    if (mevcut <= 1) {
      setState(() {
        _sepet.removeAt(index);
      });
      return;
    }

    setState(() {
      _sepet[index]['miktar'] = mevcut - 1;
    });
  }

  Future<void> _miktarGir(int index) async {
    final item = _sepet[index];
    final controller = TextEditingController(
      text: _sayi(item['miktar']).toStringAsFixed(0),
    );

    final sonuc = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Miktar Değiştir'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Miktar',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              Navigator.pop(dialogContext, _sayi(controller.text));
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, _sayi(controller.text));
              },
              child: const Text('Uygula'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (sonuc == null) return;

    if (sonuc <= 0) {
      _mesaj('Miktar sıfırdan büyük olmalıdır.', Colors.orange);
      return;
    }

    setState(() {
      _sepet[index]['miktar'] = sonuc;
    });
  }

  Widget _sepetKarti(int index) {
    final item = _sepet[index];
    final stok = item['stok'] as StokModel;
    final miktar = _sayi(item['miktar']);
    final fiyat = _sayi(item['birim_fiyat']);
    final indirim = _sayi(item['indirim']);
    final kdv = _sayi(item['kdv_orani']);
    final tutar = miktar * fiyat * (1 - indirim / 100);
    final depoAdi = _depolar
        .where((d) => int.tryParse('${d['depo_id'] ?? ''}') == _depoId)
        .map((d) => d['depo_adi']?.toString() ?? '-')
        .fold<String>('-', (onceki, deger) => deger);

    return LogoKlasikBelgeSatiri(
      no: index + 1,
      kod: markaVeUreticiKodu(stok.marka, stok.ureticiKodu),
      aciklama: stok.urunAdi,
      miktar: miktar.toStringAsFixed(0),
      birim: 'Adet',
      fiyat: _para(fiyat),
      indirim: '%${indirim.toStringAsFixed(1)}',
      kdv: '%${kdv.toStringAsFixed(0)}',
      tutar: _para(tutar),
      raf: stok.raf.trim().isEmpty ? '-' : stok.raf.trim(),
      stok: stok.stokMiktari.toStringAsFixed(0),
      ambar: depoAdi,
      onTap: () => _stokEkraniniAc(stok),
      onQuantityEdit: () => _miktarGir(index),
      onEdit: () => _alisFiyatiDegistir(index),
      onDelete: () {
        setState(() => _sepet.removeAt(index));
      },
    );
  }

  Widget _toplamKarti(String baslik, double deger, {Color? renk}) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            _para(deger),
            style: TextStyle(
              color: renk,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MobilUyum.telefon(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _duzenlemeMi
              ? 'ALIŞ İRSALİYESİ DÜZELT'
              : (widget.konsinye
                    ? 'KONSİNYE GİRİŞ İRSALİYESİ'
                    : 'YENİ ALIŞ İRSALİYESİ'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _kurumsalBelgeBasligi('ALIŞ İRSALİYESİ'),
                Card(
                  margin: const EdgeInsets.all(8),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: mobil ? double.infinity : 300,
                          child: InkWell(
                            onTap: () async {
                              final secilen = await CariSecDialog.ac(
                                context: context,
                                cariler: _cariler,
                                seciliCariId: _cariId,
                                baslik: 'Tedarikçi / Cari Seç',
                                aramaIpucu: 'Cari ünvanı ara...',
                              );

                              if (secilen == null || !mounted) return;

                              setState(() {
                                _cariId = secilen;
                              });
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Tedarikçi / Cari',
                                prefixIcon: Icon(Icons.search),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _cariId == null
                                    ? 'Cari seçin'
                                    : (_cariler
                                              .where(
                                                (c) =>
                                                    int.tryParse(
                                                      c['cari_id'].toString(),
                                                    ) ==
                                                    _cariId,
                                              )
                                              .map(
                                                (c) =>
                                                    c['unvan']?.toString() ??
                                                    '-',
                                              )
                                              .toList()
                                              .isEmpty
                                          ? 'Cari seçin'
                                          : _cariler
                                                .where(
                                                  (c) =>
                                                      int.tryParse(
                                                        c['cari_id'].toString(),
                                                      ) ==
                                                      _cariId,
                                                )
                                                .map(
                                                  (c) =>
                                                      c['unvan']?.toString() ??
                                                      '-',
                                                )
                                                .first),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: mobil ? double.infinity : 180,
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: _depoId,
                            decoration: const InputDecoration(
                              labelText: 'Depo',
                              border: OutlineInputBorder(),
                            ),
                            items: _depolar.map((depo) {
                              return DropdownMenuItem<int>(
                                value: int.tryParse(depo['depo_id'].toString()),
                                child: Text(depo['depo_adi']?.toString() ?? ''),
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
                          width: mobil ? double.infinity : 210,
                          child: TextField(
                            controller: _noController,
                            decoration: const InputDecoration(
                              labelText: 'İrsaliye No',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: mobil ? double.infinity : 360,
                          child: TextField(
                            controller: _aciklamaController,
                            decoration: const InputDecoration(
                              labelText: 'Açıklama',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Flex(
                    direction: mobil ? Axis.vertical : Axis.horizontal,
                    children: [
                      SizedBox(
                        width: mobil ? double.infinity : 470,
                        height: mobil ? 180 : null,
                        child: Card(
                          margin: const EdgeInsets.all(8),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _aramaController,
                                  onChanged: _aramaYap,
                                  decoration: const InputDecoration(
                                    hintText: 'Ürün adı, kod, OEM, barkod, marka, RAF...',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _araniyor
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : _urunler.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'Ürün aramak için yazın.',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: _urunler.length,
                                          separatorBuilder: (_, __) {
                                            return const SizedBox(height: 8);
                                          },
                                          itemBuilder: (context, index) {
                                            return _urunKarti(_urunler[index]);
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
                          margin: const EdgeInsets.all(8),
                          elevation: 0,
                          child: _sepet.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 72,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Alış irsaliyesi sepeti boş.',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Ürün arayarak alış irsaliyesine ekleyin.',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                )
                              : LogoKlasikBelgeListe(
                                  alis: true,
                                  itemCount: _sepet.length,
                                  itemBuilder: (context, index) {
                                    return _sepetKarti(index);
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: MobilYatayRow(
                    mobilDikey: true,
                    children: [
                      if (!mobil)
                        _toplamKarti(
                          'Ara Toplam',
                          _araToplam,
                          renk: Colors.blue.shade700,
                        ),
                      if (!mobil) const SizedBox(width: 8),
                      if (!mobil)
                        _toplamKarti(
                          'İskonto Toplam',
                          _iskontoToplam,
                          renk: Colors.blue.shade700,
                        ),
                      if (!mobil) const SizedBox(width: 8),
                      if (!mobil)
                        _toplamKarti(
                          'KDV Toplam',
                          _kdvToplam,
                          renk: Colors.blue.shade700,
                        ),
                      if (!mobil) const SizedBox(width: 8),
                      _toplamKarti(
                        'Genel Toplam',
                        _genelToplam,
                        renk: Colors.green.shade700,
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _sepet.isEmpty ? null : _sepetiTemizle,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Sepeti Temizle'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _kaydediliyor ? null : _kaydet,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _kaydediliyor
                              ? 'Kaydediliyor...'
                              : _duzenlemeMi
                              ? 'Değişiklikleri Kaydet'
                              : 'İrsaliyeyi Kaydet',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
