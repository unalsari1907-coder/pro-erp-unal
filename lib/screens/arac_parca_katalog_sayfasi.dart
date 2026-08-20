import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stok_model.dart';
import '../services/arac_katalog_service.dart';
import '../services/supabase_service.dart';
import 'satis_sayfasi.dart';
import '../widgets/erp_detay_dialog.dart';

class AracParcaKatalogSayfasi extends StatefulWidget {
  const AracParcaKatalogSayfasi({super.key});

  @override
  State<AracParcaKatalogSayfasi> createState() =>
      _AracParcaKatalogSayfasiState();
}

class _AracParcaKatalogSayfasiState extends State<AracParcaKatalogSayfasi> {
  final TextEditingController _q = TextEditingController();
  final TextEditingController _parcaQ = TextEditingController();
  final ScrollController _parcaScrollController = ScrollController();
  Timer? _aramaDebounce;
  int _aramaNesli = 0;
  int _aracSecimNesli = 0;
  final List<Map<String, dynamic>> _aracGecmisi = <Map<String, dynamic>>[];

  bool _yukleniyor = false;
  bool _aktariliyor = false;

  List<Map<String, dynamic>> _araclar = <Map<String, dynamic>>[];
  Map<String, dynamic>? _secilen;
  List<Map<String, dynamic>> _parcalar = <Map<String, dynamic>>[];
  String? _hata;
  String _kategoriFiltre = 'Tümü';
  Map<int, String> _aracOemDurumlari = <int, String>{};

  @override
  void initState() {
    super.initState();
    _ara();
  }

  @override
  void dispose() {
    _aramaDebounce?.cancel();
    _q.dispose();
    _parcaQ.dispose();
    _parcaScrollController.dispose();
    super.dispose();
  }

  int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

  String _s(dynamic v) => v?.toString().trim() ?? '';

  void _canliAra(String _) {
    _aramaDebounce?.cancel();
    _aramaDebounce = Timer(const Duration(milliseconds: 350), _ara);
  }

  Future<void> _ara() async {
    final nesil = ++_aramaNesli;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    try {
      final liste = await AracKatalogService.aracAra(_q.text);
      if (!mounted || nesil != _aramaNesli) return;

      // Önce araç listesini göster; OEM doluluk sayacı kullanıcıyı bekletmesin.
      setState(() {
        _araclar = liste;
        _aracOemDurumlari = <int, String>{};
        _yukleniyor = false;
        if (liste.isEmpty) {
          _hata = 'Araç bulunamadı. Katalog Excel/CSV dosyanızı içe aktarabilirsiniz.';
        }
      });

      if (liste.isNotEmpty) {
        // Listeyi hemen göster; OEM durumlarını paralel ve arkadan doldur.
        Future.wait(liste.map((arac) async {
          final id = _int(arac['arac_id']);
          if (id <= 0) return MapEntry(id, '0/0');
          try {
            final parcalar = await AracKatalogService.parcalariGetir(id);

            // Araç detay ekranındaki TÜMÜ sayacı ile birebir aynı hesap.
            final gruplar = <String, List<Map<String, dynamic>>>{};
            for (final parca in parcalar) {
              final hamKod = _s(parca['kategori_kodu']);
              final kod = hamKod.isEmpty
                  ? 'PARCA_${_int(parca['parca_id'])}'
                  : _birlesikRlKategoriKodu(hamKod);
              gruplar
                  .putIfAbsent(kod, () => <Map<String, dynamic>>[])
                  .add(parca);
            }

            final toplam = gruplar.length;
            final dolu = gruplar.values
                .where(
                  (grup) => grup.any(
                    (parca) => _s(parca['oem_kodu']).isNotEmpty,
                  ),
                )
                .length;

            return MapEntry(id, '$dolu/$toplam');
          } catch (_) {
            return MapEntry(id, '0/0');
          }
        })).then((entries) {
          if (!mounted || nesil != _aramaNesli) return;
          setState(() {
            _aracOemDurumlari = <int, String>{
              for (final e in entries) e.key: e.value,
            };
          });
        });
      }

    } catch (e) {
      if (!mounted || nesil != _aramaNesli) return;
      setState(() {
        _yukleniyor = false;
        _hata = '$e';
      });
    }
  }

  Future<void> _aracSec(
    Map<String, dynamic> arac, {
    bool gecmiseEkle = true,
    bool kategoriSifirla = true,
  }) async {
    final nesil = ++_aracSecimNesli;
    final onceki = _secilen;
    if (gecmiseEkle && onceki != null && onceki['arac_id'] != arac['arac_id']) {
      _aracGecmisi.add(Map<String, dynamic>.from(onceki));
    }

    setState(() {
      _secilen = arac;
      if (kategoriSifirla) _kategoriFiltre = 'Tümü';
      if (kategoriSifirla) _parcaQ.clear();
      _parcalar = <Map<String, dynamic>>[];
      _yukleniyor = true;
    });

    try {
      final parcalar = await AracKatalogService.parcalariGetir(
        _int(arac['arac_id']),
      );
      if (!mounted || nesil != _aracSecimNesli) return;

      setState(() {
        _parcalar = parcalar;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = '$e';
        _yukleniyor = false;
      });
    }
  }

  Future<void> _iceAktar() async {
    final secim = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['xlsx', 'xls', 'csv'],
      withData: true,
    );

    if (secim == null || secim.files.isEmpty) return;

    final dosya = secim.files.first;
    // Telefonda çok büyük Excel/CSV dosyasını RAM'e almak tarayıcı sekmesini
    // kapatabilir. 20 MB üstünü masaüstünden içe aktarmak daha güvenlidir.
    if (dosya.size > 20 * 1024 * 1024) {
      _mesaj(
        "Dosya 20 MB’dan büyük. Büyük katalog aktarımını bilgisayardan yapın.",
        hata: true,
      );
      return;
    }
    if (dosya.bytes == null) {
      _mesaj('Dosya okunamadı.', hata: true);
      return;
    }

    setState(() => _aktariliyor = true);

    try {
      final sonuc = await AracKatalogService.iceAktar(dosya.bytes!, dosya.name);
      if (!mounted) return;

      _mesaj(
        '${sonuc.aracSayisi} araç, ${sonuc.parcaSayisi} parça kaydı aktarıldı. '
        'Atlanan: ${sonuc.atlananSatir}',
      );
      await _ara();
    } catch (e) {
      if (mounted) {
        _mesaj('İçe aktarma hatası: $e', hata: true);
      }
    } finally {
      if (mounted) {
        setState(() => _aktariliyor = false);
      }
    }
  }

  void _mesaj(String mesaj, {bool hata = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: hata ? Colors.red : null),
    );
  }

  Future<void> _kopyala(String metin, String etiket) async {
    final temiz = metin.trim();
    if (temiz.isEmpty) {
      _mesaj('$etiket boş.', hata: true);
      return;
    }
    await Clipboard.setData(ClipboardData(text: temiz));
    if (mounted) _mesaj('$etiket kopyalandı: $temiz');
  }

  String _parcaUstKategori(Map<String, dynamic> parca) {
    final nitelik = _s(parca['nitelik']);
    const prefix = 'UST_KATEGORI:';
    if (nitelik.toUpperCase().startsWith(prefix)) {
      final deger = nitelik.substring(prefix.length).trim();
      if (deger.isNotEmpty) return deger;
    }
    return _ustKategori(_s(parca['kategori_adi']));
  }

  Future<void> _yeniAracEkle() async {
    final uretici = TextEditingController();
    final model = TextEditingController();
    final yil = TextEditingController();
    final yillar = TextEditingController();
    final motor = TextEditingController();
    final yakit = TextEditingController();
    final motorKodu = TextEditingController();
    final sase = TextEditingController();
    final plaka = TextEditingController();
    final notlar = TextEditingController();
    final sahip = TextEditingController();
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yeni Araç Katalog Kaydı'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: uretici,
                    decoration: const InputDecoration(
                      labelText: 'Üretici *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: model,
                    decoration: const InputDecoration(
                      labelText: 'Model *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: yil,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Model Yılı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: yillar,
                    decoration: const InputDecoration(
                      labelText: 'Uyum Aralığı',
                      hintText: '2015-2024',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: motor,
                    decoration: const InputDecoration(
                      labelText: 'Motor',
                      hintText: '2.0',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: yakit,
                    decoration: const InputDecoration(
                      labelText: 'Yakıt',
                      hintText: 'DİZEL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: motorKodu,
                    decoration: const InputDecoration(
                      labelText: 'Motor Kodu',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 310,
                  child: TextField(
                    controller: sase,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Şase',
                      hintText: 'Aynı şase varsa kayıt engellenir',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: plaka,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Plaka',
                      hintText: '58 ABC 123',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 310,
                  child: TextField(
                    controller: sahip,
                    decoration: const InputDecoration(
                      labelText: 'Araç Sahibi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 640,
                  child: TextField(
                    controller: notlar,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Not',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (kaydet != true) {
      for (final c in <TextEditingController>[
        uretici,
        model,
        yil,
        yillar,
        motor,
        yakit,
        motorKodu,
        sase,
        plaka,
        notlar,
        sahip,
      ])
        c.dispose();
      return;
    }
    if (uretici.text.trim().isEmpty || model.text.trim().isEmpty) {
      _mesaj('Üretici ve model zorunludur.', hata: true);
      for (final c in <TextEditingController>[
        uretici,
        model,
        yil,
        yillar,
        motor,
        yakit,
        motorKodu,
        sase,
        plaka,
        notlar,
        sahip,
      ])
        c.dispose();
      return;
    }
    try {
      final girilenSase = sase.text.trim();
      if (girilenSase.isNotEmpty) {
        final ayniSase = await AracKatalogService.saseIleAracBul(girilenSase);
        if (ayniSase != null) {
          if (mounted) {
            _mesaj(
              'Aynı şaseli araç var: ${_s(ayniSase['uretici'])} ${_s(ayniSase['model'])} ${_s(ayniSase['yil'])}',
              hata: true,
            );
          }
          return;
        }
      }
      final yeni = await AracKatalogService.aracEkle(
        uretici: uretici.text,
        model: model.text,
        yil: int.tryParse(yil.text.trim()),
        yillar: yillar.text,
        motor: motor.text,
        yakit: yakit.text,
        motorKodu: motorKodu.text,
        sase: sase.text,
        plaka: plaka.text,
        notlar: notlar.text,
        aracSahibi: sahip.text,
      );
      if (!mounted) return;

      // 2.5.4: Yeni araç kaydından sonra eski 500 araçlık listeyi tekrar
      // indirme. Yeni kaydı doğrudan yerel listenin başına ekleyip aç.
      // Böylece kullanıcı kayıt sonrası uzun yükleme ekranı görmez.
      setState(() {
        _araclar = <Map<String, dynamic>>[
          Map<String, dynamic>.from(yeni),
          ..._araclar.where((e) => e['arac_id'] != yeni['arac_id']),
        ];
      });
      await _aracSec(yeni, gecmiseEkle: false);
      _mesaj('Yeni araç katalog kaydı oluşturuldu.');
    } catch (e) {
      if (mounted) _mesaj('Araç kaydedilemedi: $e', hata: true);
    } finally {
      for (final c in <TextEditingController>[
        uretici,
        model,
        yil,
        yillar,
        motor,
        yakit,
        motorKodu,
        sase,
        plaka,
        notlar,
        sahip,
      ])
        c.dispose();
    }
  }

  Future<void> _aracDetayDuzenle() async {
    final arac = _secilen;
    if (arac == null) return;

    final uretici = TextEditingController(text: _s(arac['uretici']));
    final model = TextEditingController(text: _s(arac['model']));
    final yil = TextEditingController(text: _s(arac['yil']));
    final yillar = TextEditingController(text: _s(arac['yillar']));
    final motor = TextEditingController(text: _s(arac['motor']));
    final yakit = TextEditingController(text: _s(arac['yakit']));
    final motorKodu = TextEditingController(text: _s(arac['motor_kodu']));
    final sase = TextEditingController(text: _s(arac['sase']));
    final plaka = TextEditingController(text: _s(arac['plaka']));
    final notlar = TextEditingController(text: _s(arac['notlar']));
    final sahip = TextEditingController(text: _s(arac['arac_sahibi']));
    final controllers = <TextEditingController>[
      uretici,
      model,
      yil,
      yillar,
      motor,
      yakit,
      motorKodu,
      sase,
      plaka,
      notlar,
      sahip,
    ];

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final ekran = MediaQuery.sizeOf(dialogContext);
        final mobil = ekran.width < 720;
        final genisAlan = mobil
            ? (ekran.width - 96).clamp(220.0, 620.0).toDouble()
            : 620.0;
        final yarimAlan = mobil ? genisAlan : 290.0;
        return AlertDialog(
          title: const Row(
            children: <Widget>[
              Icon(Icons.edit_road_rounded),
              SizedBox(width: 10),
              Text('Araç Katalog Detayını Düzenle'),
            ],
          ),
          content: SizedBox(
            width: mobil ? genisAlan : 760,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  SizedBox(
                    width: mobil ? genisAlan : 230,
                    child: TextField(
                      controller: uretici,
                      decoration: const InputDecoration(
                        labelText: 'Üretici *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobil ? genisAlan : 230,
                    child: TextField(
                      controller: model,
                      decoration: const InputDecoration(
                        labelText: 'Model *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobil ? yarimAlan : 150,
                    child: TextField(
                      controller: yil,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Model Yılı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobil ? yarimAlan : 210,
                    child: TextField(
                      controller: yillar,
                      decoration: const InputDecoration(
                        labelText: 'Uyum Aralığı',
                        hintText: '2015-2024',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobil ? yarimAlan : 175,
                    child: TextField(
                      controller: motor,
                      decoration: const InputDecoration(
                        labelText: 'Motor',
                        hintText: '2.0',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobil ? yarimAlan : 175,
                    child: TextField(
                      controller: yakit,
                      decoration: const InputDecoration(
                        labelText: 'Yakıt',
                        hintText: 'DİZEL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobil ? genisAlan : 220,
                    child: TextField(
                      controller: motorKodu,
                      decoration: const InputDecoration(
                        labelText: 'Motor Kodu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobil ? genisAlan : 360,
                    child: TextField(
                      controller: sase,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Şase',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.copy_rounded),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobil ? genisAlan : 220,
                    child: TextField(
                      controller: plaka,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Plaka',
                        hintText: '58 ABC 123',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobil ? genisAlan : 360,
                    child: TextField(
                      controller: sahip,
                      decoration: const InputDecoration(
                        labelText: 'Araç Sahibi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobil ? genisAlan : 735,
                    child: TextField(
                      controller: notlar,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Not / Ek Bilgi',
                        hintText: 'Örn: Klimasız, şasiye göre farklılık gösterir, özel donanım, müşteri notu...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('İptal'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Değişiklikleri Kaydet'),
            ),
          ],
        );
      },
    );

    if (kaydet != true) {
      for (final c in controllers) c.dispose();
      return;
    }
    if (uretici.text.trim().isEmpty || model.text.trim().isEmpty) {
      _mesaj('Üretici ve model zorunludur.', hata: true);
      for (final c in controllers) c.dispose();
      return;
    }

    final eskiKategori = _kategoriFiltre;
    final eskiScroll = _parcaScrollController.hasClients
        ? _parcaScrollController.offset
        : 0.0;
    try {
      final guncel = await AracKatalogService.aracGuncelle(
        aracId: _int(arac['arac_id']),
        uretici: uretici.text,
        model: model.text,
        yil: int.tryParse(yil.text.trim()),
        yillar: yillar.text,
        motor: motor.text,
        yakit: yakit.text,
        motorKodu: motorKodu.text,
        sase: sase.text,
        notlar: notlar.text,
        aracSahibi: sahip.text,
      );
      if (!mounted) return;
      setState(() {
        _secilen = guncel;
        _kategoriFiltre = eskiKategori;
        final idx = _araclar.indexWhere(
          (x) => _int(x['arac_id']) == _int(guncel['arac_id']),
        );
        if (idx >= 0) _araclar[idx] = Map<String, dynamic>.from(guncel);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_parcaScrollController.hasClients) {
          final max = _parcaScrollController.position.maxScrollExtent;
          _parcaScrollController.jumpTo(eskiScroll.clamp(0.0, max).toDouble());
        }
      });
      _mesaj('Araç katalog detayları güncellendi.');
    } catch (e) {
      if (mounted) _mesaj('Araç bilgileri güncellenemedi: $e', hata: true);
    } finally {
      for (final c in controllers) c.dispose();
    }
  }

  Future<void> _aracSil() async {
    final arac = _secilen;
    if (arac == null) return;

    final aracId = _int(arac['arac_id']);
    final aracAdi = <String>[
      _s(arac['uretici']),
      _s(arac['model']),
      _s(arac['yil']),
    ].where((e) => e.isNotEmpty).join(' ');

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.red,
          size: 42,
        ),
        title: const Text('Araç kaydı silinsin mi?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            '$aracAdi aracı ve yalnız bu araca bağlı ${_parcalar.length} '
            'katalog satırı kalıcı olarak silinecek. Bu işlem geri alınamaz.',
            textAlign: TextAlign.center,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Aracı Sil'),
          ),
        ],
      ),
    );
    if (onay != true) return;

    setState(() => _yukleniyor = true);
    try {
      await AracKatalogService.aracSil(aracId: aracId);
      if (!mounted) return;
      setState(() {
        _araclar.removeWhere((x) => _int(x['arac_id']) == aracId);
        _aracGecmisi.removeWhere((x) => _int(x['arac_id']) == aracId);
        _secilen = null;
        _parcalar = <Map<String, dynamic>>[];
        _kategoriFiltre = 'Tümü';
        _yukleniyor = false;
      });
      _mesaj('$aracAdi araç kataloğundan silindi.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _mesaj('Araç silinemedi: $e', hata: true);
    }
  }

  Future<void> _yeniParcaEkle() async {
    final arac = _secilen;
    if (arac == null) return;
    final ust = TextEditingController(
      text: _kategoriFiltre == 'Tümü' ? '' : _kategoriFiltre,
    );
    final ad = TextEditingController();
    final oem = TextEditingController();
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yeni Parça / OEM Katalog Kaydı'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: ust,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Üst Kategori',
                  hintText: 'Örn: Sensörler, Hortumlar, Elektrik, Soğutma',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ad,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Parça Adı *',
                  hintText: 'Örn: Turbo Basınç Sensörü / Radyatör Hortumu',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: oem,
                textCapitalization: TextCapitalization.characters,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'OEM Numarası (isteğe bağlı)',
                  hintText:
                      'Birden fazla OEM için her satıra bir kod yazabilirsiniz',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Kataloğa Ekle'),
          ),
        ],
      ),
    );
    if (kaydet != true) {
      ust.dispose();
      ad.dispose();
      oem.dispose();
      return;
    }
    if (ad.text.trim().isEmpty) {
      _mesaj('Parça adı zorunludur.', hata: true);
      ust.dispose();
      ad.dispose();
      oem.dispose();
      return;
    }
    final secilecekKategori = ust.text.trim().isEmpty
        ? 'Diğer'
        : ust.text.trim();
    try {
      await AracKatalogService.parcaEkle(
        aracId: _int(arac['arac_id']),
        ustKategori: secilecekKategori,
        parcaAdi: ad.text,
        oemKodu: oem.text,
      );
      if (!mounted) return;
      await _aracSec(arac, gecmiseEkle: false, kategoriSifirla: false);
      setState(() => _kategoriFiltre = secilecekKategori);
      _mesaj('Yeni parça katalog kaydı eklendi.');
    } catch (e) {
      if (mounted) _mesaj('Parça eklenemedi: $e', hata: true);
    } finally {
      ust.dispose();
      ad.dispose();
      oem.dispose();
    }
  }

  Future<void> _parcaTamDuzenle(Map<String, dynamic> parca) async {
    final ust = TextEditingController(text: _parcaUstKategori(parca));
    final ad = TextEditingController(text: _standartParcaAdi(_s(parca['kategori_adi'])));
    final oem = TextEditingController(text: _s(parca['oem_kodu']));
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Katalog Kaydını Düzenle'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: ust,
                decoration: const InputDecoration(
                  labelText: 'Üst Kategori',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ad,
                decoration: const InputDecoration(
                  labelText: 'Parça Adı *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: oem,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'OEM Numarası',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Not: Üst kategori veya parça adı değişirse aynı parça bütün araçlarda güncellenir. OEM numarası yalnız bu araç için değişir.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (kaydet != true) {
      ust.dispose();
      ad.dispose();
      oem.dispose();
      return;
    }
    try {
      await AracKatalogService.parcaGuncelle(
        parcaId: _int(parca['parca_id']),
        ustKategori: ust.text,
        parcaAdi: ad.text,
        oemKodu: oem.text,
        mevcutKategoriKodu: _s(parca['kategori_kodu']),
      );
      final arac = _secilen;
      if (arac != null && mounted) {
        final kategori = ust.text.trim().isEmpty ? 'Diğer' : ust.text.trim();
        await _aracSec(arac, gecmiseEkle: false, kategoriSifirla: false);
        setState(() => _kategoriFiltre = kategori);
      }
      if (mounted) _mesaj('Katalog kaydı güncellendi.');
    } catch (e) {
      if (mounted) _mesaj('Kayıt güncellenemedi: $e', hata: true);
    } finally {
      ust.dispose();
      ad.dispose();
      oem.dispose();
    }
  }

  Future<void> _aracListesineDon() async {
    if (_aracGecmisi.isNotEmpty) {
      final onceki = _aracGecmisi.removeLast();
      await _aracSec(onceki, gecmiseEkle: false, kategoriSifirla: false);
      return;
    }
    setState(() {
      _secilen = null;
      _parcalar = <Map<String, dynamic>>[];
      _kategoriFiltre = 'Tümü';
      _hata = null;
    });
    await _ara();
  }

  Future<void> _parcaSil(Map<String, dynamic> parca) async {
    final arac = _secilen;
    if (arac == null) return;
    final kod = _s(parca['kategori_kodu']);
    final ad = _s(parca['kategori_adi']);
    final ozel = kod.startsWith('OZEL_');

    final secim = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$ad • Parçayı Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Nasıl silmek istediğinizi seçin.'),
            const SizedBox(height: 12),
            const Text('• Bu Araçtan Sil: Yalnız açık olan araçtan kaldırır.'),
            if (ozel) ...<Widget>[
              const SizedBox(height: 6),
              const Text(
                '• Tüm Katalogdan Sil: Bu parçayı bütün araçlardan ve ortak parça şablonundan kaldırır.',
              ),
            ] else ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Bu parça standart katalog kalemidir. Yanlışlıkla bütün katalogdan silinmemesi için global silme kapalıdır.',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'arac'),
            icon: const Icon(Icons.directions_car_outlined),
            label: const Text('Bu Araçtan Sil'),
          ),
          if (ozel)
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'global'),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Tüm Katalogdan Sil'),
            ),
        ],
      ),
    );
    if (secim == null) return;

    if (secim == 'global') {
      final onay = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tüm Katalogdan Silinsin mi?'),
          content: Text(
            '“$ad” bütün araç kataloglarından kaldırılacak ve yeni araçlara artık eklenmeyecek. Bu işlem geri alınamaz.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Evet, Tamamen Sil'),
            ),
          ],
        ),
      );
      if (onay != true) return;
    }

    try {
      if (secim == 'global') {
        await AracKatalogService.parcaGlobalSil(kategoriKodu: kod);
      } else {
        await AracKatalogService.parcaAractanSil(
          aracId: _int(arac['arac_id']),
          kategoriKodu: kod,
        );
      }
      if (!mounted) return;
      setState(() {
        _parcalar.removeWhere((p) => _s(p['kategori_kodu']) == kod);
      });
      _mesaj(
        secim == 'global'
            ? '$ad tüm katalogdan silindi.'
            : '$ad bu araçtan silindi.',
      );
    } catch (e) {
      if (mounted) _mesaj('Parça silinemedi: $e', hata: true);
    }
  }

  Future<void> _oemDuzenle(Map<String, dynamic> parca) async {
    final mevcutOem = _s(parca['oem_kodu']);
    final controller = TextEditingController(text: mevcutOem);
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_s(parca['kategori_adi'])} • OEM Güncelle'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                mevcutOem.isEmpty
                    ? 'Bu parça için OEM numarası katalogda yazmıyor. OEM numarasını buradan ekleyebilirsiniz.'
                    : 'Mevcut OEM numarasını buradan değiştirebilir veya düzeltebilirsiniz.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'OEM Numarası',
                  hintText: 'OEM numarasını girin',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
                onSubmitted: (_) => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (kaydet != true) {
      controller.dispose();
      return;
    }

    final yeniOem = controller.text.trim();
    controller.dispose();
    if (yeniOem.isEmpty) {
      _mesaj('OEM numarası boş bırakılamaz.', hata: true);
      return;
    }

    try {
      await AracKatalogService.parcaOemGuncelle(
        parcaId: _int(parca['parca_id']),
        oemKodu: yeniOem,
      );
      if (!mounted) return;
      final mevcutIndex = _parcalar.indexWhere(
        (x) => _int(x['parca_id']) == _int(parca['parca_id']),
      );
      if (mevcutIndex >= 0) {
        setState(() {
          _parcalar[mevcutIndex] = <String, dynamic>{
            ..._parcalar[mevcutIndex],
            'oem_kodu': yeniOem,
            'ham_deger': yeniOem,
          };
        });
      }
      _mesaj(
        mevcutOem.isEmpty
            ? 'OEM numarası kaydedildi.'
            : 'OEM numarası güncellendi.',
      );
    } catch (e) {
      if (mounted) _mesaj('OEM kaydedilemedi: $e', hata: true);
    }
  }

  Future<void> _oemEkle(Map<String, dynamic> parca) async {
    final controller = TextEditingController();
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_s(parca['kategori_adi'])} • OEM Ekle'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Yeni OEM Numarası',
              hintText: 'Örn: 77364857',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.add_link_rounded),
            ),
            onSubmitted: (_) => Navigator.pop(dialogContext, true),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.add_rounded),
            label: const Text('OEM Ekle'),
          ),
        ],
      ),
    );
    if (kaydet != true) {
      controller.dispose();
      return;
    }
    final yeni = controller.text.trim();
    controller.dispose();
    if (yeni.isEmpty) {
      _mesaj('OEM numarası boş bırakılamaz.', hata: true);
      return;
    }
    final arac = _secilen;
    if (arac == null) return;
    try {
      await AracKatalogService.parcaOemEkle(
        aracId: _int(arac['arac_id']),
        kategoriKodu: _s(parca['kategori_kodu']),
        kategoriAdi: _s(parca['kategori_adi']),
        oemKodu: yeni,
        nitelik: _s(parca['nitelik']),
        sira: _int(parca['sira']),
      );
      await _aracSec(arac, gecmiseEkle: false, kategoriSifirla: false);
      if (mounted) _mesaj('OEM eklendi. Her OEM ayrı ayrı aranabilir.');
    } catch (e) {
      if (mounted) _mesaj('OEM eklenemedi: $e', hata: true);
    }
  }

  Future<void> _oemSil(Map<String, dynamic> parca) async {
    final oem = _s(parca['oem_kodu']);
    if (oem.isEmpty) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('OEM Sil'),
        content: Text('$oem OEM numarası bu araç/parçadan kaldırılsın mı?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await AracKatalogService.parcaOemSil(parcaId: _int(parca['parca_id']));
      final arac = _secilen;
      if (arac != null)
        await _aracSec(arac, gecmiseEkle: false, kategoriSifirla: false);
      if (mounted) _mesaj('OEM kaldırıldı.');
    } catch (e) {
      if (mounted) _mesaj('OEM silinemedi: $e', hata: true);
    }
  }

  List<String> _oemKodlari(String ham) {
    return ham
        .split(RegExp(r'[,;\n/]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  String _normKod(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<void> _stoklariGoster(
    Map<String, dynamic> parca, {
    String? tekOem,
  }) async {
    final hamKod = tekOem?.trim().isNotEmpty == true
        ? tekOem!.trim()
        : _s(parca['oem_kodu']);
    final kodlar = _oemKodlari(hamKod);

    if (kodlar.isEmpty) {
      await _oemDuzenle(parca);
      return;
    }

    final Map<int, StokModel> bulunan = <int, StokModel>{};
    for (final kod in kodlar) {
      final sonuc = await SupabaseService.stoklariGetir(aramaMetni: kod);
      for (final stok in sonuc) {
        final hedef = _normKod(kod);
        final tamEslesme = stok.oemler.any((o) => _normKod(o) == hedef);
        if (tamEslesme) bulunan[stok.stokId] = stok;
      }
    }
    if (!mounted) return;
    final stoklar = bulunan.values.toList()
      ..sort((a, b) {
        final sa = a.stokMiktari > 0 ? 0 : 1;
        final sb = b.stokMiktari > 0 ? 0 : 1;
        if (sa != sb) return sa.compareTo(sb);
        return a.marka.compareTo(b.marka);
      });

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final mobil = size.width < 760;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: mobil ? 10 : 28,
            vertical: mobil ? 12 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1080,
              maxHeight: size.height * .92,
            ),
            child: Padding(
              padding: EdgeInsets.all(mobil ? 14 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _s(parca['kategori_adi']),
                          style: TextStyle(
                            fontSize: mobil ? 20 : 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    'Kategori: ${_ustKategori(_s(parca['kategori_adi']))} › ${_s(parca['kategori_adi'])}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  if (stoklar.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.info_outline,
                            size: 19,
                            color: Colors.orange.shade900,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'OEM $hamKod için ${stoklar.length} ürün bulundu.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: stoklar.isEmpty
                        ? Center(
                            child: Text(
                              'OEM $hamKod için stokta tam eşleşen ürün bulunamadı.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: stoklar.length,
                            itemBuilder: (_, index) =>
                                _stokTile(dialogContext, stoklar[index]),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Fiyatlar stok kartındaki satış fiyatından alınır.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Kapat'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _gosterilecekSatisFiyati(StokModel stok) {
    if (stok.satisFiyatiPerakende > 0) {
      return stok.satisFiyatiPerakende;
    }
    if (stok.satisFiyatiListe > 0) {
      return stok.satisFiyatiListe;
    }
    if (stok.satisFiyatiIndirimli > 0) {
      return stok.satisFiyatiIndirimli;
    }
    if (stok.satisFiyatiToptan > 0) {
      return stok.satisFiyatiToptan;
    }
    return 0;
  }

  Future<void> _satisaEkle(BuildContext dialogContext, StokModel stok) async {
    if (stok.stokMiktari <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu ürünün stoğu yok. Satışa eklenemez.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(dialogContext).pop();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SatisSayfasi(baslangicStok: stok),
      ),
    );
  }

  void _resmiBuyut(BuildContext context, StokModel stok, int baslangic) {
    final resimler = stok.resimler.where((e) => e.trim().isNotEmpty).toList();
    if (resimler.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.92),
      builder: (_) => _TamEkranResim(resimler: resimler, baslangic: baslangic),
    );
  }

  Widget _urunResmi(BuildContext dialogContext, StokModel stok) {
    final url = stok.resim.trim();
    return InkWell(
      onTap: url.isEmpty ? null : () => _resmiBuyut(dialogContext, stok, 0),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 190,
        height: 145,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: url.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 38,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Resim yok',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  ),
                  Positioned(
                    left: 7,
                    bottom: 7,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.zoom_in_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _stokTile(BuildContext dialogContext, StokModel stok) {
    final fiyat = _gosterilecekSatisFiyati(stok);
    final stokVar = stok.stokMiktari > 0;
    final ureticiKodu = stok.ureticiKodu.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dar = constraints.maxWidth < 760;
            final bilgi = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 30,
                  runSpacing: 12,
                  children: <Widget>[
                    _alan(
                      'Marka',
                      stok.marka.isEmpty ? '-' : stok.marka,
                      vurgu: true,
                    ),
                    _alan(
                      'Üretici Kodu',
                      ureticiKodu.isEmpty ? '-' : ureticiKodu,
                      vurgu: true,
                    ),
                    SizedBox(
                      width: dar ? 260 : 330,
                      child: _alan('Ürün Adı', stok.urunAdi, vurgu: true),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    border: Border.all(color: Colors.blueGrey.shade100),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _alan(
                    'Ürün Özelliği',
                    stok.urunOzellik.trim().isEmpty
                        ? '-'
                        : stok.urunOzellik.trim(),
                    vurgu: stok.urunOzellik.trim().isNotEmpty,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 34,
                  runSpacing: 10,
                  children: <Widget>[
                    _alan('Raf', stok.raf.isEmpty ? '-' : stok.raf),
                    _alan(
                      'Stok',
                      stok.stokMiktari.toStringAsFixed(0),
                      renk: stokVar ? Colors.green.shade700 : Colors.red,
                    ),
                    _alan(
                      'Satış Fiyatı',
                      fiyat > 0
                          ? '${fiyat.toStringAsFixed(2)} ₺'
                          : 'Tanımlı değil',
                      renk: fiyat > 0
                          ? Colors.blue.shade800
                          : Colors.orange.shade800,
                      vurgu: true,
                    ),
                  ],
                ),
              ],
            );

            final butonlar = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: stokVar
                      ? () => _satisaEkle(dialogContext, stok)
                      : null,
                  icon: Icon(
                    stokVar
                        ? Icons.add_shopping_cart_rounded
                        : Icons.remove_shopping_cart_rounded,
                  ),
                  label: Text(stokVar ? 'Satışa Ekle' : 'Stok Yok'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ErpDetayDialog.goster(
                      dialogContext,
                      baslik: 'Stok Detayı',
                      altBaslik: stok.urunAdi,
                      veri: <String, dynamic>{
                        'Stok ID': stok.stokId,
                        'Ürün': stok.urunAdi,
                        'Üretici Kodu': ureticiKodu.isEmpty ? '-' : ureticiKodu,
                        'Marka': stok.marka,
                        'Ürün Özelliği': stok.urunOzellik.trim().isEmpty
                            ? '-'
                            : stok.urunOzellik.trim(),
                        'Raf': stok.raf,
                        'Stok': stok.stokMiktari,
                        'Perakende': stok.satisFiyatiPerakende,
                        'Toptan': stok.satisFiyatiToptan,
                        'Liste': stok.satisFiyatiListe,
                      },
                    );
                  },
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Stok Detayı'),
                ),
              ],
            );

            if (dar) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(child: _urunResmi(dialogContext, stok)),
                  const SizedBox(height: 14),
                  bilgi,
                  const SizedBox(height: 14),
                  butonlar,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _urunResmi(dialogContext, stok),
                const SizedBox(width: 18),
                Expanded(child: bilgi),
                const SizedBox(width: 18),
                SizedBox(width: 165, child: butonlar),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _alan(String baslik, String deger, {bool vurgu = false, Color? renk}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          baslik,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 3),
        Text(
          deger.isEmpty ? '-' : deger,
          style: TextStyle(
            fontSize: 15,
            fontWeight: vurgu ? FontWeight.w700 : FontWeight.w600,
            color: renk,
          ),
        ),
      ],
    );
  }

  Widget _miniBilgi(
    String baslik,
    String deger, {
    bool vurgu = false,
    Color? renk,
  }) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
        children: <InlineSpan>[
          TextSpan(
            text: '$baslik: ',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          TextSpan(
            text: deger,
            style: TextStyle(
              color: renk,
              fontWeight: vurgu ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MediaQuery.sizeOf(context).width < 850;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARAÇ → PARÇA KATALOĞU'),
        actions: <Widget>[
          if (mobil)
            IconButton(
              tooltip: 'Yeni Araç',
              onPressed: _yeniAracEkle,
              icon: const Icon(Icons.add_rounded),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.tonalIcon(
                onPressed: _yeniAracEkle,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Yeni Araç'),
              ),
            ),
          const SizedBox(width: 8),
          if (mobil)
            IconButton(
              tooltip: 'Excel / CSV İçe Aktar',
              onPressed: _aktariliyor ? null : _iceAktar,
              icon: _aktariliyor
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.tonalIcon(
                onPressed: _aktariliyor ? null : _iceAktar,
                icon: _aktariliyor
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: const Text('Excel / CSV İçe Aktar'),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _ara,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _q,
              onChanged: _canliAra,
              onSubmitted: (_) { _aramaDebounce?.cancel(); _ara(); },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.directions_car_rounded),
                hintText: 'Google tarzı ara: model, motor, şase veya plaka (58 ABC 123)...',
                suffixIcon: _q.text.isEmpty
                    ? IconButton(
                        onPressed: _ara,
                        icon: const Icon(Icons.search_rounded),
                      )
                    : IconButton(
                        tooltip: 'Aramayı temizle',
                        onPressed: () {
                          _aramaDebounce?.cancel();
                          _q.clear();
                          _ara();
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _yukleniyor && _secilen == null
                  ? const Center(child: CircularProgressIndicator())
                  : mobil
                  ? _mobilGorunum()
                  : _masaustuGorunum(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _masaustuGorunum() {
    if (_secilen != null) {
      return Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: _aracListesineDon,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(
                  _aracGecmisi.isNotEmpty
                      ? 'Önceki Sayfaya Dön'
                      : 'Araç Listesine Geri Dön',
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: _aracDetayDuzenle,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Araç Detayını Düzenle'),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                  backgroundColor: Colors.red.shade50,
                ),
                onPressed: _aracSil,
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Araç Sil'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _yeniParcaEkle,
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Yeni Parça / OEM'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _parcaPaneli()),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(width: 380, child: _aracListesi()),
        const VerticalDivider(width: 18),
        Expanded(child: _parcaPaneli()),
      ],
    );
  }

  Widget _mobilGorunum() {
    if (_secilen == null) return _aracListesi();

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextButton.icon(
                onPressed: _aracListesineDon,
                icon: const Icon(Icons.arrow_back),
                label: Text(
                  _aracGecmisi.isNotEmpty
                      ? 'Önceki sayfaya dön'
                      : 'Araç listesine dön',
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Araç Detayını Düzenle',
              onPressed: _aracDetayDuzenle,
              icon: const Icon(Icons.edit_rounded),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Araç Sil',
              style: IconButton.styleFrom(
                foregroundColor: Colors.red.shade800,
                backgroundColor: Colors.red.shade50,
              ),
              onPressed: _aracSil,
              icon: const Icon(Icons.delete_forever_rounded),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Yeni Parça / OEM',
              onPressed: _yeniParcaEkle,
              icon: const Icon(Icons.add_box_rounded),
            ),
          ],
        ),
        Expanded(child: _parcaPaneli()),
      ],
    );
  }


  String _birlesikRlKategoriKodu(String raw) { var kod = raw.trim().toUpperCase(); if (kod.endsWith('_SAG')) kod = kod.substring(0, kod.length - 4); if (kod.endsWith('_SOL')) kod = kod.substring(0, kod.length - 4); return kod; }
  String _standartParcaAdi(String raw) { var x = raw.trim().toUpperCase(); const from = 'ÇĞİÖŞÜÂÊÎÔÛ'; const to = 'CGIOSUAEIOU'; for (var i = 0; i < from.length; i++) { x = x.replaceAll(from[i], to[i]); } final rl = RegExp(r'(?:\s+R/L|\s+R L|\s+RL|\s+SAG|\s+SOL)$').hasMatch(x); x = x.replaceFirst(RegExp(r'(?:\s+R/L|\s+R L|\s+RL|\s+SAG|\s+SOL)$'), '').replaceAll(RegExp(r'\s+'), ' ').trim(); return rl && x.isNotEmpty ? '$x R/L' : x; }
  Color _durumRengi(int tamam, int toplam) { if (toplam > 0 && tamam >= toplam) return Colors.green; if (tamam > 0) return Colors.orange; return Colors.red; }

  Widget _aracListesi() {
    if (_araclar.isEmpty) {
      return Center(
        child: Text(
          _hata ?? 'Katalog boş. Excel / CSV ile içe aktarın.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Card(
      child: ListView.separated(
        itemCount: _araclar.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final arac = _araclar[index];
          final secili = _secilen?['arac_id'] == arac['arac_id'];
          final oemDurumu =
              _aracOemDurumlari[_int(arac['arac_id'])] ?? '...';
          final parcalar = oemDurumu.split('/');
          final oemDolu = parcalar.isNotEmpty
              ? int.tryParse(parcalar.first) ?? 0
              : 0;
          final oemToplam = parcalar.length > 1
              ? int.tryParse(parcalar[1]) ?? 0
              : 0;
          final oemYuklendi = oemDurumu != '...';
          final oemTamam = oemToplam > 0 && oemDolu >= oemToplam;
          final durumRengi = !oemYuklendi
              ? Colors.blueGrey
              : (oemDolu == 0
                    ? Colors.red
                    : (oemTamam ? Colors.green : Colors.orange));
          final arkaPlan = durumRengi.withOpacity(
            secili ? 0.16 : 0.07,
          );

          return ColoredBox(
            color: arkaPlan,
            child: ListTile(
            selected: secili,
            leading: Icon(
              Icons.directions_car_filled_rounded,
              color: durumRengi,
            ),
            title: Text(
              '${_s(arac['uretici'])} ${_s(arac['model'])}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Model Yılı: ${_s(arac['yil']).isNotEmpty ? _s(arac['yil']) : '-'} • '
              'Uyum Aralığı: ${_s(arac['yillar']).isNotEmpty ? _s(arac['yillar']) : (_s(arac['yil']).isNotEmpty ? _s(arac['yil']) : '-')} • '
              '${_s(arac['motor'])} ${_s(arac['yakit'])}\n'
              'Motor: ${_s(arac['motor_kodu'])} • Plaka: ${_s(arac['plaka']).isEmpty ? '-' : _s(arac['plaka'])} • Şase: ${_s(arac['sase'])}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: durumRengi.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: durumRengi.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    'OEM $oemDurumu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: durumRengi,
                    ),
                  ),
                ),
                if (_s(arac['sase']).isNotEmpty)
                  IconButton(
                    tooltip: 'Şaseyi Kopyala',
                    onPressed: () => _kopyala(_s(arac['sase']), 'Şase'),
                    icon: const Icon(Icons.copy_rounded),
                  ),
              ],
            ),
            onTap: () => _aracSec(arac),
          ),
          );
        },
      ),
    );
  }

  String _ustKategori(String ad) {
    final x = ad.toLowerCase();
    if (x.contains('filtre')) return 'Filtreler';
    if (x.contains('tapa') || x == 'buji' || x.contains('buji kablo'))
      return 'Bakım';
    if (x.contains('disk') ||
        x.contains('balata') ||
        x.contains('kampana') ||
        x.contains('fren'))
      return 'Fren Sistemi';
    if (x.contains('debriyaj')) return 'Debriyaj';
    if (x.contains('triger') || x.contains('motor') || x.contains('bobin'))
      return 'Motor';
    if (x.contains('kayış') ||
        x.contains('kayis') ||
        x.contains('rulman') ||
        x.contains('avare'))
      return 'Kayış - Rulman';
    if (x.contains('amortis') ||
        x.contains('salıncak') ||
        x.contains('salincak') ||
        x.contains('z rot') ||
        x.contains('viraj'))
      return 'Süspansiyon';
    if (x.contains('rot') || x.contains('direksiyon')) return 'Direksiyon';
    if (x.contains('kablo') ||
        x.contains('elektr') ||
        x.contains('sensör') ||
        x.contains('sensor') ||
        x.contains('müşür') ||
        x.contains('musur'))
      return 'Elektrik';
    if (x.contains('termostat') ||
        x.contains('su pompa') ||
        x.contains('pompa') ||
        x.contains('hortum'))
      return 'Soğutma';
    if (x.contains('far') || x.contains('ampul') || x.contains('aydın'))
      return 'Aydınlatma';
    return 'Diğer';
  }

  Widget _parcaPaneli() {
    if (_secilen == null)
      return const Center(child: Text('Soldan bir araç seçin.'));
    if (_yukleniyor) return const Center(child: CircularProgressIndicator());

    final arac = _secilen!;
    // 2.5.5: Aynı parça altında birden fazla OEM ayrı DB satırı olabilir.
    // Ekranda parçayı bir kez gösterip OEM'leri altında bağımsız arama düğmeleri yapıyoruz.
    final gruplar = <String, List<Map<String, dynamic>>>{};
    for (final p in _parcalar) {
      final hamKod = _s(p['kategori_kodu']);
      final kod = hamKod.isEmpty ? 'PARCA_${_int(p['parca_id'])}' : _birlesikRlKategoriKodu(hamKod);
      gruplar.putIfAbsent(kod, () => <Map<String, dynamic>>[]).add(p);
    }
    final parcaGruplari = gruplar.values.toList()
      ..sort((a, b) => _int(a.first['sira']).compareTo(_int(b.first['sira'])));

    final parcaArama = _parcaQ.text.trim().toUpperCase();
    bool parcaEslesiyor(List<Map<String, dynamic>> grup) {
      if (parcaArama.isEmpty) return true;
      final haystack = <String>[
        _s(grup.first['kategori_adi']),
        _parcaUstKategori(grup.first),
        _s(grup.first['kategori_kodu']),
        ...grup.map((p) => _s(p['oem_kodu'])),
      ].join(' ').toUpperCase();
      final kelimeler = parcaArama.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
      return kelimeler.every(haystack.contains);
    }

    final kategoriler = <String, int>{}; final kategoriTamam = <String, int>{};
    for (final grup in parcaGruplari) { final k = _parcaUstKategori(grup.first); kategoriler[k] = (kategoriler[k] ?? 0) + 1; if (grup.any((p) => _s(p['oem_kodu']).isNotEmpty)) kategoriTamam[k] = (kategoriTamam[k] ?? 0) + 1; }
    final gorunen = parcaGruplari
        .where((g) => _kategoriFiltre == 'Tümü' || _parcaUstKategori(g.first) == _kategoriFiltre)
        .where(parcaEslesiyor)
        .toList();

    final mobil = MediaQuery.sizeOf(context).width < 1000;
    final kategoriSirasi = <String>[
      'Tümü',
      'Bakım',
      'Filtreler',
      'Fren Sistemi',
      'Debriyaj',
      'Motor',
      'Kayış - Rulman',
      'Süspansiyon',
      'Direksiyon',
      'Elektrik',
      'Soğutma',
      'Aydınlatma',
      'Diğer',
    ];
    final ekstraKategoriler =
        kategoriler.keys.where((k) => !kategoriSirasi.contains(k)).toList()
          ..sort();
    kategoriSirasi.addAll(ekstraKategoriler);

    final kategoriPanel = Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'KATEGORİLER',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...kategoriSirasi
                .where((k) => k == 'Tümü' || (kategoriler[k] ?? 0) > 0)
                .map((k) {
                  final adet = k == 'Tümü' ? parcaGruplari.length : (kategoriler[k] ?? 0);
                  final tamam = k == 'Tümü' ? parcaGruplari.where((g) => g.any((p) => _s(p['oem_kodu']).isNotEmpty)).length : (kategoriTamam[k] ?? 0);
                  final secili = _kategoriFiltre == k; final renk = _durumRengi(tamam, adet);
                  return Container(margin: const EdgeInsets.symmetric(vertical: 2), decoration: BoxDecoration(color: renk.withOpacity(0.08), border: Border.all(color: renk.withOpacity(0.28)), borderRadius: BorderRadius.circular(9)), child: ListTile(dense: true, selected: secili, leading: Icon(tamam >= adet && adet > 0 ? Icons.check_circle : Icons.timelapse_rounded, size: 18, color: renk), title: Text(k.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: TextStyle(color: renk, fontWeight: secili ? FontWeight.w800 : FontWeight.w700, fontSize: 12)), trailing: Text('$tamam/$adet', style: TextStyle(color: renk, fontWeight: FontWeight.w800, fontSize: 11)), onTap: () => setState(() => _kategoriFiltre = k)));
                }),
          ],
        ),
      ),
    );

    final urunPanel = gorunen.isEmpty
        ? const Center(child: Text('Bu kategoride parça kaydı yok.'))
        : ListView.separated(
            controller: _parcaScrollController,
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: gorunen.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final grup = gorunen[i];
              final ana = grup.first;
              final oemSatirlari = grup
                  .where((p) => _s(p['oem_kodu']).isNotEmpty)
                  .toList();
              return Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const CircleAvatar(child: Icon(Icons.settings_rounded)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    _standartParcaAdi(_s(ana['kategori_adi'])),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'OEM Ekle',
                                  onPressed: () => _oemEkle(ana),
                                  icon: const Icon(
                                    Icons.add_circle_outline_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Parça / Kategori Düzenle',
                                  onPressed: () => _parcaTamDuzenle(ana),
                                  icon: Icon(
                                    Icons.edit_rounded,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Parçayı Sil',
                                  onPressed: () => _parcaSil(ana),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                            if (oemSatirlari.isEmpty)
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _oemEkle(ana),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 17,
                                        color: Colors.orange.shade800,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'OEM YAZMIYOR',
                                        style: TextStyle(
                                          color: Colors.orange.shade900,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('• OEM eklemek için tıklayın'),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...oemSatirlari.asMap().entries.map((entry) {
                                final p = entry.value;
                                final oem = _s(p['oem_kodu']);
                                return Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Text(
                                        'OEM ${entry.key + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          oem,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'OEM Kopyala',
                                        onPressed: () => _kopyala(oem, 'OEM'),
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 19,
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Bu OEM ile stokta ara',
                                        onPressed: () =>
                                            _stoklariGoster(p, tekOem: oem),
                                        icon: const Icon(
                                          Icons.search_rounded,
                                          size: 21,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        tooltip: 'OEM İşlemleri',
                                        onSelected: (v) {
                                          if (v == 'duzenle') _oemDuzenle(p);
                                          if (v == 'sil') _oemSil(p);
                                        },
                                        itemBuilder: (_) =>
                                            const <PopupMenuEntry<String>>[
                                              PopupMenuItem(
                                                value: 'duzenle',
                                                child: Text('OEM Düzenle'),
                                              ),
                                              PopupMenuItem(
                                                value: 'sil',
                                                child: Text('OEM Sil'),
                                              ),
                                            ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: <Widget>[
                _bilgi('Araç', '${_s(arac['uretici'])} ${_s(arac['model'])}'),
                _bilgi(
                  'Model Yılı',
                  _s(arac['yil']).isNotEmpty ? _s(arac['yil']) : '-',
                ),
                _bilgi(
                  'Uyum Aralığı',
                  _s(arac['yillar']).isNotEmpty
                      ? _s(arac['yillar'])
                      : (_s(arac['yil']).isNotEmpty ? _s(arac['yil']) : '-'),
                ),
                _bilgi(
                  'Motor',
                  '${_s(arac['motor'])} ${_s(arac['motor_kodu'])}',
                ),
                _bilgi('Yakıt', _s(arac['yakit'])),
                _kopyalanabilirBilgi('Plaka', _s(arac['plaka']), 'Plaka'),
                _kopyalanabilirBilgi('Şase', _s(arac['sase']), 'Şase'),
                if (_s(arac['arac_sahibi']).isNotEmpty)
                  _bilgi('Araç Sahibi', _s(arac['arac_sahibi'])),
                if (_s(arac['notlar']).isNotEmpty)
                  SizedBox(
                    width: mobil ? double.infinity : 520,
                    child: _bilgi('Not / Ek Bilgi', _s(arac['notlar'])),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _parcaQ,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.manage_search_rounded),
            hintText: 'Parça, OEM veya kategori ara (örn: yağ filtresi, 55230822, fren)...',
            suffixIcon: _parcaQ.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Parça aramasını temizle',
                    onPressed: () {
                      _parcaQ.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _parcalar.isEmpty
              ? const Center(child: Text('Bu araç için parça kaydı yok.'))
              : mobil
              ? Column(
                  children: <Widget>[
                    SizedBox(
                      height: 54,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: kategoriSirasi
                            .where(
                              (k) => k == 'Tümü' || (kategoriler[k] ?? 0) > 0,
                            )
                            .map((k) {
                              final adet = k == 'Tümü'
                                  ? _parcalar.length
                                  : (kategoriler[k] ?? 0);
                              return Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  label: Text('$k • $adet'),
                                  selected: _kategoriFiltre == k,
                                  onSelected: (_) =>
                                      setState(() => _kategoriFiltre = k),
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                    Expanded(child: urunPanel),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 230,
                      child: SingleChildScrollView(child: kategoriPanel),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: urunPanel),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _kopyalanabilirBilgi(String baslik, String deger, String etiket) {
    return SizedBox(
      width: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _bilgi(baslik, deger)),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '$etiket Kopyala',
            onPressed: deger.trim().isEmpty
                ? null
                : () => _kopyala(deger, etiket),
            icon: const Icon(Icons.copy_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _bilgi(String baslik, String deger) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            baslik,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            deger.isEmpty ? '-' : deger,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TamEkranResim extends StatefulWidget {
  final List<String> resimler;
  final int baslangic;
  const _TamEkranResim({required this.resimler, required this.baslangic});

  @override
  State<_TamEkranResim> createState() => _TamEkranResimState();
}

class _TamEkranResimState extends State<_TamEkranResim> {
  late int index = widget.baslangic;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.7,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  widget.resimler[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 20,
            child: IconButton.filled(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          if (widget.resimler.length > 1) ...<Widget>[
            Positioned(
              left: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filled(
                  onPressed: () => setState(
                    () => index =
                        (index - 1 + widget.resimler.length) %
                        widget.resimler.length,
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filled(
                  onPressed: () => setState(
                    () => index = (index + 1) % widget.resimler.length,
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
          ],
          Positioned(
            left: 0,
            right: 0,
            bottom: 22,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${index + 1} / ${widget.resimler.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
