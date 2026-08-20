import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';
import '../services/supabase_service.dart';

class GiderMasrafSayfasi extends StatefulWidget {
  const GiderMasrafSayfasi({super.key});

  @override
  State<GiderMasrafSayfasi> createState() =>
      _GiderMasrafSayfasiState();
}

class _GiderMasrafSayfasiState
    extends State<GiderMasrafSayfasi> {
  final TextEditingController _aramaController =
      TextEditingController();

  bool _yukleniyor = true;
  bool _kaydediliyor = false;

  DateTime _baslangic = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _bitis = DateTime.now();

  String _kategoriFiltresi = 'TÜMÜ';

  List<Map<String, dynamic>> _giderler = [];
  List<Map<String, dynamic>> _kasalar = [];
  List<Map<String, dynamic>> _cariler = [];

  static const List<String> _kategoriler = [
    'Kira',
    'Elektrik',
    'Su',
    'Doğalgaz',
    'İnternet / Telefon',
    'Maaş',
    'SGK',
    'Vergi',
    'Muhasebe',
    'Nakliye',
    'Yemek',
    'Yakıt',
    'Araç Gideri',
    'Bakım / Onarım',
    'Kırtasiye',
    'Banka Masrafı',
    'POS Komisyonu',
    'Komisyon',
    'Sigorta',
    'Temizlik',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();

    _aramaController.addListener(() {
      if (mounted) setState(() {});
    });

    _verileriYukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  double _sayi(dynamic deger) {
    return double.tryParse(
          deger?.toString().replaceAll(',', '.') ?? '0',
        ) ??
        0;
  }

  int? _int(dynamic deger) {
    return int.tryParse(deger?.toString() ?? '');
  }

  String _metin(dynamic deger) {
    final sonuc = deger?.toString().trim() ?? '';
    return sonuc.isEmpty ? '-' : sonuc;
  }

  String _para(dynamic deger) {
    return '${_sayi(deger).toStringAsFixed(2)} ₺';
  }

  String _tarih(dynamic deger) {
    final raw = deger?.toString() ?? '';
    final t = DateTime.tryParse(raw)?.toLocal();
    if (t == null) return raw.isEmpty ? '-' : raw;

    return '${t.day.toString().padLeft(2, '0')}.'
        '${t.month.toString().padLeft(2, '0')}.'
        '${t.year} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  String _kisaTarih(DateTime t) {
    return '${t.day.toString().padLeft(2, '0')}.'
        '${t.month.toString().padLeft(2, '0')}.'
        '${t.year}';
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

  bool _iptalMi(Map<String, dynamic> gider) {
    return gider['iptal'] == true ||
        gider['iptal']?.toString().toLowerCase() ==
            'true';
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
            .from('giderler')
            .select(
              'gider_id, gider_no, tarih, kategori, tutar, '
              'kasa_id, cari_id, belge_no, aciklama, kullanici, '
              'iptal, iptal_tarihi, iptal_aciklama',
            )
            .gte('tarih', baslangicIso)
            .lte('tarih', bitisIso)
            .order('tarih', ascending: false),
        SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi, kasa_tipi')
            .order('kasa_adi'),
        SupabaseService.supabase
            .from('cariler')
            .select('cari_id, unvan, cari_tipi')
            .order('unvan'),
      ]);

      if (!mounted) return;

      setState(() {
        _giderler =
            List<Map<String, dynamic>>.from(
          sonuclar[0] as List,
        );

        _kasalar =
            List<Map<String, dynamic>>.from(
          sonuclar[1] as List,
        );

        _cariler =
            List<Map<String, dynamic>>.from(
          sonuclar[2] as List,
        );

        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _yukleniyor = false);

      _mesaj(
        'Giderler yüklenemedi: $e',
        Colors.red,
      );
    }
  }

  List<Map<String, dynamic>> get _gorunenGiderler {
    final kelimeler = _aramaController.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    return _giderler.where((gider) {
      if (_kategoriFiltresi != 'TÜMÜ' &&
          _metin(gider['kategori']) !=
              _kategoriFiltresi) {
        return false;
      }

      if (kelimeler.isEmpty) return true;

      final metin = [
        gider['gider_no'],
        gider['kategori'],
        gider['belge_no'],
        gider['aciklama'],
        gider['kullanici'],
        _kasaAdi(gider['kasa_id']),
        _cariAdi(gider['cari_id']),
      ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();

      return kelimeler.every(metin.contains);
    }).toList();
  }

  double get _toplamGider {
    return _gorunenGiderler
        .where((e) => !_iptalMi(e))
        .fold<double>(
          0,
          (toplam, e) =>
              toplam + _sayi(e['tutar']),
        );
  }

  double get _iptalToplam {
    return _gorunenGiderler
        .where(_iptalMi)
        .fold<double>(
          0,
          (toplam, e) =>
              toplam + _sayi(e['tutar']),
        );
  }

  Future<void> _tarihSec({
    required bool baslangic,
  }) async {
    final secilen = await showDatePicker(
      context: context,
      initialDate:
          baslangic ? _baslangic : _bitis,
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

  Future<int?> _kasaSec(
    BuildContext dialogContext,
    int? mevcut,
  ) async {
    return showDialog<int>(
      context: dialogContext,
      builder: (context) {
        String arama = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final liste = _kasalar.where((kasa) {
              if (arama.isEmpty) return true;

              final metin = [
                kasa['kasa_adi'],
                kasa['kasa_tipi'],
              ]
                  .map((e) => e?.toString() ?? '')
                  .join(' ')
                  .toLowerCase();

              return metin.contains(
                arama.toLowerCase(),
              );
            }).toList();

            return AlertDialog(
              title: const Text(
                'Kasa / Banka / POS Seç',
              ),
              content: MobilDialogIcerik(
                width: 650,
                height: 520,
                child: Column(
                  children: [
                    TextField(
                      onChanged: (deger) {
                        setDialogState(() {
                          arama = deger.trim();
                        });
                      },
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Hesap ara...',
                        prefixIcon:
                            Icon(Icons.search),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: liste.length,
                        separatorBuilder:
                            (_, __) =>
                                const Divider(
                          height: 1,
                        ),
                        itemBuilder:
                            (_, index) {
                          final kasa =
                              liste[index];

                          final id =
                              _int(
                            kasa['kasa_id'],
                          );

                          return ListTile(
                            selected:
                                id == mevcut,
                            leading:
                                const CircleAvatar(
                              child: Icon(
                                Icons
                                    .account_balance_wallet_outlined,
                              ),
                            ),
                            title: Text(
                              _metin(
                                kasa[
                                    'kasa_adi'],
                              ),
                            ),
                            subtitle: Text(
                              'Tip: ${_metin(kasa['kasa_tipi'])}',
                            ),
                            trailing:
                                const Icon(
                              Icons
                                  .chevron_right,
                            ),
                            onTap: () {
                              if (id != null) {
                                Navigator.pop(
                                  context,
                                  id,
                                );
                              }
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
  }

  Future<int?> _cariSec(
    BuildContext dialogContext,
    int? mevcut,
  ) async {
    return showDialog<int>(
      context: dialogContext,
      builder: (context) {
        String arama = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final liste = _cariler.where((cari) {
              if (arama.isEmpty) return true;

              final metin = [
                cari['unvan'],
                cari['cari_tipi'],
              ]
                  .map((e) => e?.toString() ?? '')
                  .join(' ')
                  .toLowerCase();

              return metin.contains(
                arama.toLowerCase(),
              );
            }).toList();

            return AlertDialog(
              title:
                  const Text('Cari Seç (Opsiyonel)'),
              content: MobilDialogIcerik(
                width: 650,
                height: 520,
                child: Column(
                  children: [
                    TextField(
                      onChanged: (deger) {
                        setDialogState(() {
                          arama = deger.trim();
                        });
                      },
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Cari ara...',
                        prefixIcon:
                            Icon(Icons.search),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: liste.length,
                        separatorBuilder:
                            (_, __) =>
                                const Divider(
                          height: 1,
                        ),
                        itemBuilder:
                            (_, index) {
                          final cari =
                              liste[index];

                          final id =
                              _int(
                            cari['cari_id'],
                          );

                          return ListTile(
                            selected:
                                id == mevcut,
                            leading:
                                const CircleAvatar(
                              child: Icon(
                                Icons.person_outline,
                              ),
                            ),
                            title: Text(
                              _metin(
                                cari['unvan'],
                              ),
                            ),
                            subtitle: Text(
                              'Tip: ${_metin(cari['cari_tipi'])}',
                            ),
                            onTap: () {
                              if (id != null) {
                                Navigator.pop(
                                  context,
                                  id,
                                );
                              }
                            },
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
                    Navigator.pop(
                      context,
                      -1,
                    );
                  },
                  child: const Text(
                    'Cariyi Temizle',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _yeniGider() async {
    String kategori = 'Diğer';
    int? kasaId;
    int? cariId;
    DateTime tarih = DateTime.now();

    final tutarController =
        TextEditingController();

    final belgeController =
        TextEditingController();

    final aciklamaController =
        TextEditingController();

    final kullaniciController =
        TextEditingController(
      text: 'admin',
    );

    final kaydedildi =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: MobilDialogIcerik(
                width: 850,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      MobilYatayRow(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                Colors.red
                                    .shade50,
                            child: Icon(
                              Icons
                                  .receipt_long,
                              color: Colors.red
                                  .shade700,
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          const Expanded(
                            child: Text(
                              'YENİ GİDER / MASRAF',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                                false,
                              );
                            },
                            icon: const Icon(
                              Icons.close,
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                        height: 28,
                      ),
                      MobilYatayRow(
                        children: [
                          Expanded(
                            child:
                                DropdownButtonFormField<
                                    String>(
                              value: kategori,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Gider Türü',
                                border:
                                    OutlineInputBorder(),
                              ),
                              items: _kategoriler
                                  .map(
                                    (e) =>
                                        DropdownMenuItem(
                                      value: e,
                                      child:
                                          Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged:
                                  (deger) {
                                if (deger ==
                                    null) {
                                  return;
                                }

                                setDialogState(
                                  () {
                                    kategori =
                                        deger;
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final secilen =
                                    await showDatePicker(
                                  context:
                                      dialogContext,
                                  initialDate:
                                      tarih,
                                  firstDate:
                                      DateTime(
                                    2020,
                                  ),
                                  lastDate:
                                      DateTime(
                                    2100,
                                  ),
                                );

                                if (secilen ==
                                    null) {
                                  return;
                                }

                                setDialogState(
                                  () {
                                    tarih =
                                        DateTime(
                                      secilen
                                          .year,
                                      secilen
                                          .month,
                                      secilen
                                          .day,
                                      DateTime
                                              .now()
                                          .hour,
                                      DateTime
                                              .now()
                                          .minute,
                                    );
                                  },
                                );
                              },
                              child:
                                  InputDecorator(
                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Tarih',
                                  border:
                                      OutlineInputBorder(),
                                  suffixIcon:
                                      Icon(
                                    Icons
                                        .calendar_month,
                                  ),
                                ),
                                child: Text(
                                  _kisaTarih(
                                    tarih,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller:
                            tutarController,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Tutar (₺)',
                          prefixIcon: Icon(
                            Icons.payments,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      MobilYatayRow(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final secilen =
                                    await _kasaSec(
                                  dialogContext,
                                  kasaId,
                                );

                                if (secilen !=
                                    null) {
                                  setDialogState(
                                    () {
                                      kasaId =
                                          secilen;
                                    },
                                  );
                                }
                              },
                              child:
                                  InputDecorator(
                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Ödeme Hesabı *',
                                  border:
                                      OutlineInputBorder(),
                                  suffixIcon:
                                      Icon(
                                    Icons
                                        .search,
                                  ),
                                ),
                                child: Text(
                                  kasaId == null
                                      ? 'Kasa / Banka / POS seç'
                                      : _kasaAdi(
                                          kasaId,
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final secilen =
                                    await _cariSec(
                                  dialogContext,
                                  cariId,
                                );

                                if (secilen ==
                                    -1) {
                                  setDialogState(
                                    () {
                                      cariId =
                                          null;
                                    },
                                  );
                                } else if (secilen !=
                                    null) {
                                  setDialogState(
                                    () {
                                      cariId =
                                          secilen;
                                    },
                                  );
                                }
                              },
                              child:
                                  InputDecorator(
                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Cari (Opsiyonel)',
                                  border:
                                      OutlineInputBorder(),
                                  suffixIcon:
                                      Icon(
                                    Icons
                                        .person_search,
                                  ),
                                ),
                                child: Text(
                                  cariId == null
                                      ? 'Cari seçilmedi'
                                      : _cariAdi(
                                          cariId,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      MobilYatayRow(
                        children: [
                          Expanded(
                            child: TextField(
                              controller:
                                  belgeController,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Belge / Fatura No',
                                border:
                                    OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: TextField(
                              controller:
                                  kullaniciController,
                              decoration:
                                  const InputDecoration(
                                labelText:
                                    'Kullanıcı',
                                border:
                                    OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextField(
                        controller:
                            aciklamaController,
                        minLines: 3,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Açıklama',
                          hintText:
                              'Örn: Ağustos dükkan kirası, elektrik faturası...',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      MobilYatayRow(
                        children: [
                          const Expanded(
                            child: Text(
                              '* Gider kaydedildiğinde seçilen hesaptan otomatik ÇIKIŞ hareketi oluşur.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                                false,
                              );
                            },
                            child:
                                const Text(
                              'Vazgeç',
                            ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          ElevatedButton.icon(
                            onPressed:
                                _kaydediliyor
                                    ? null
                                    : () async {
                                        final tutar =
                                            _sayi(
                                          tutarController
                                              .text,
                                        );

                                        if (tutar <=
                                            0) {
                                          _mesaj(
                                            'Tutar 0’dan büyük olmalıdır.',
                                            Colors.red,
                                          );
                                          return;
                                        }

                                        if (kasaId ==
                                            null) {
                                          _mesaj(
                                            'Ödeme hesabı seçmelisin.',
                                            Colors.red,
                                          );
                                          return;
                                        }

                                        setDialogState(
                                          () {
                                            _kaydediliyor =
                                                true;
                                          },
                                        );

                                        try {
                                          await SupabaseService
                                              .supabase
                                              .rpc(
                                            'gider_kaydet',
                                            params: {
                                              'p_tarih':
                                                  tarih
                                                      .toUtc()
                                                      .toIso8601String(),
                                              'p_kategori':
                                                  kategori,
                                              'p_tutar':
                                                  tutar,
                                              'p_kasa_id':
                                                  kasaId,
                                              'p_cari_id':
                                                  cariId,
                                              'p_belge_no':
                                                  belgeController
                                                      .text
                                                      .trim(),
                                              'p_aciklama':
                                                  aciklamaController
                                                      .text
                                                      .trim(),
                                              'p_kullanici':
                                                  kullaniciController
                                                      .text
                                                      .trim(),
                                            },
                                          );

                                          if (!dialogContext
                                              .mounted) {
                                            return;
                                          }

                                          Navigator.pop(
                                            dialogContext,
                                            true,
                                          );
                                        } catch (e) {
                                          setDialogState(
                                            () {
                                              _kaydediliyor =
                                                  false;
                                            },
                                          );

                                          _mesaj(
                                            'Gider kaydedilemedi: $e',
                                            Colors.red,
                                          );
                                        }
                                      },
                            icon:
                                _kaydediliyor
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons
                                            .save,
                                      ),
                            label:
                                const Text(
                              'Gideri Kaydet',
                            ),
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
      },
    );

    tutarController.dispose();
    belgeController.dispose();
    aciklamaController.dispose();
    kullaniciController.dispose();

    if (kaydedildi == true) {
      _mesaj(
        'Gider başarıyla kaydedildi.',
        Colors.green,
      );

      await _verileriYukle();
    }
  }

  Future<void> _giderDetay(
    Map<String, dynamic> gider,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final iptal = _iptalMi(gider);

        return Dialog(
          child: MobilDialogIcerik(
            width: 760,
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  MobilYatayRow(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: iptal
                            ? Colors.grey
                            : Colors.red,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          'Gider Detayı: ${_metin(gider['gider_no'])}',
                          style:
                              const TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      if (iptal)
                        const Chip(
                          label:
                              Text('İPTAL'),
                        ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                          );
                        },
                        icon: const Icon(
                          Icons.close,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  _detaySatiri(
                    'Tarih',
                    _tarih(gider['tarih']),
                  ),
                  _detaySatiri(
                    'Kategori',
                    _metin(
                      gider['kategori'],
                    ),
                  ),
                  _detaySatiri(
                    'Tutar',
                    _para(gider['tutar']),
                  ),
                  _detaySatiri(
                    'Ödeme Hesabı',
                    _kasaAdi(
                      gider['kasa_id'],
                    ),
                  ),
                  _detaySatiri(
                    'Cari',
                    _cariAdi(
                      gider['cari_id'],
                    ),
                  ),
                  _detaySatiri(
                    'Belge No',
                    _metin(
                      gider['belge_no'],
                    ),
                  ),
                  _detaySatiri(
                    'Kullanıcı',
                    _metin(
                      gider['kullanici'],
                    ),
                  ),
                  _detaySatiri(
                    'Açıklama',
                    _metin(
                      gider['aciklama'],
                    ),
                  ),
                  if (iptal) ...[
                    const Divider(),
                    _detaySatiri(
                      'İptal Tarihi',
                      _tarih(
                        gider[
                            'iptal_tarihi'],
                      ),
                    ),
                    _detaySatiri(
                      'İptal Açıklama',
                      _metin(
                        gider[
                            'iptal_aciklama'],
                      ),
                    ),
                  ],
                  const SizedBox(
                    height: 14,
                  ),
                  MobilYatayRow(
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    children: [
                      if (!iptal)
                        OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(
                              dialogContext,
                            );

                            await _giderIptal(
                              gider,
                            );
                          },
                          icon: const Icon(
                            Icons.cancel,
                          ),
                          label: const Text(
                            'Gideri İptal Et',
                          ),
                        ),
                      const SizedBox(
                        width: 8,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                          );
                        },
                        child:
                            const Text('Kapat'),
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

  Widget _detaySatiri(
    String baslik,
    String deger,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: MobilYatayRow(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              baslik,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              deger,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _giderIptal(
    Map<String, dynamic> gider,
  ) async {
    final aciklamaController =
        TextEditingController();

    final onay =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('Gider İptali'),
          content: MobilDialogIcerik(
            width: 520,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  '${_metin(gider['gider_no'])} numaralı '
                  '${_para(gider['tutar'])} gider iptal edilecek.\n\n'
                  'İptal işleminde ödeme hesabına otomatik GİRİŞ hareketi oluşturulur.',
                ),
                const SizedBox(
                  height: 12,
                ),
                TextField(
                  controller:
                      aciklamaController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'İptal Açıklaması',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('Vazgeç'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon:
                  const Icon(Icons.cancel),
              label:
                  const Text('İptal Et'),
            ),
          ],
        );
      },
    );

    if (onay != true) {
      aciklamaController.dispose();
      return;
    }

    try {
      await SupabaseService.supabase.rpc(
        'gider_iptal',
        params: {
          'p_gider_id':
              _int(gider['gider_id']),
          'p_aciklama':
              aciklamaController.text.trim(),
          'p_kullanici': 'admin',
        },
      );

      aciklamaController.dispose();

      _mesaj(
        'Gider iptal edildi.',
        Colors.orange,
      );

      await _verileriYukle();
    } catch (e) {
      aciklamaController.dispose();

      _mesaj(
        'Gider iptal edilemedi: $e',
        Colors.red,
      );
    }
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
          padding:
              const EdgeInsets.all(14),
          child: MobilYatayRow(
            children: [
              CircleAvatar(
                backgroundColor:
                    renk.withOpacity(0.12),
                child: Icon(
                  ikon,
                  color: renk,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      baslik,
                      style:
                          const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      deger,
                      style: TextStyle(
                        color: renk,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 16,
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

  @override
  Widget build(BuildContext context) {
    final liste = _gorunenGiderler;

    final aktifSayisi =
        liste.where((e) => !_iptalMi(e)).length;

    final iptalSayisi =
        liste.where(_iptalMi).length;

    return Scaffold(
      backgroundColor:
          Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'GİDER / MASRAF YÖNETİMİ',
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
            icon:
                const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        
            ],
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _yeniGider,
        icon: const Icon(Icons.add),
        label:
            const Text('Yeni Gider'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment:
                  WrapCrossAlignment
                      .center,
              children: [
                SizedBox(
                  width: 340,
                  child: TextField(
                    controller:
                        _aramaController,
                    decoration:
                        InputDecoration(
                      hintText:
                          'Gider, belge no, cari, hesap, açıklama...',
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
                SizedBox(
                  width: 210,
                  child:
                      DropdownButtonFormField<
                          String>(
                    value:
                        _kategoriFiltresi,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Kategori',
                      border:
                          OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'TÜMÜ',
                        child:
                            Text('Tüm Kategoriler'),
                      ),
                      ..._kategoriler.map(
                        (e) =>
                            DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ),
                      ),
                    ],
                    onChanged: (deger) {
                      if (deger == null) {
                        return;
                      }

                      setState(() {
                        _kategoriFiltresi =
                            deger;
                      });
                    },
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
                  icon:
                      const Icon(Icons.event),
                  label: Text(
                    'Bitiş: ${_kisaTarih(_bitis)}',
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
              minWidth: 760,
              children: [
                _ozetKarti(
                  baslik:
                      'Toplam Gider',
                  deger:
                      _para(_toplamGider),
                  ikon:
                      Icons.trending_down,
                  renk: Colors.red,
                ),
                const SizedBox(width: 8),
                _ozetKarti(
                  baslik:
                      'Aktif Gider',
                  deger:
                      '$aktifSayisi',
                  ikon:
                      Icons.receipt_long,
                  renk: Colors.blue,
                ),
                const SizedBox(width: 8),
                _ozetKarti(
                  baslik:
                      'İptal Edilen',
                  deger:
                      '$iptalSayisi',
                  ikon: Icons.cancel,
                  renk: Colors.orange,
                ),
                const SizedBox(width: 8),
                _ozetKarti(
                  baslik:
                      'İptal Toplamı',
                  deger:
                      _para(_iptalToplam),
                  ikon:
                      Icons.undo,
                  renk:
                      Colors.blueGrey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _yukleniyor
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : liste.isEmpty
                    ? const Center(
                        child: Text(
                          'Gider / masraf kaydı bulunamadı.',
                          style: TextStyle(
                            fontSize: 17,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets
                                .all(12),
                        itemCount:
                            liste.length,
                        separatorBuilder:
                            (_, __) =>
                                const SizedBox(
                          height: 8,
                        ),
                        itemBuilder:
                            (context, index) {
                          final gider =
                              liste[index];

                          final iptal =
                              _iptalMi(
                            gider,
                          );

                          return Card(
                            color: iptal
                                ? Colors.grey
                                    .shade100
                                : null,
                            child: ListTile(
                              onTap: () =>
                                  _giderDetay(
                                gider,
                              ),
                              leading:
                                  CircleAvatar(
                                backgroundColor:
                                    (iptal
                                            ? Colors
                                                .grey
                                            : Colors
                                                .red)
                                        .withOpacity(
                                  0.12,
                                ),
                                child: Icon(
                                  iptal
                                      ? Icons
                                          .block
                                      : Icons
                                          .receipt_long,
                                  color: iptal
                                      ? Colors
                                          .grey
                                      : Colors
                                          .red,
                                ),
                              ),
                              title: Text(
                                '${_metin(gider['kategori'])} • ${_metin(gider['gider_no'])}',
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  decoration:
                                      iptal
                                          ? TextDecoration
                                              .lineThrough
                                          : null,
                                ),
                              ),
                              subtitle:
                                  Text(
                                '${_tarih(gider['tarih'])}\n'
                                'Hesap: ${_kasaAdi(gider['kasa_id'])} • '
                                'Cari: ${_cariAdi(gider['cari_id'])}\n'
                                'Belge: ${_metin(gider['belge_no'])} • '
                                '${_metin(gider['aciklama'])}',
                                maxLines: 3,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                              trailing:
                                  SizedBox(
                                width: 180,
                                child: MobilYatayRow(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .end,
                                  children: [
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .end,
                                      children: [
                                        Text(
                                          _para(
                                            gider[
                                                'tutar'],
                                          ),
                                          style:
                                              TextStyle(
                                            color: iptal
                                                ? Colors
                                                    .grey
                                                : Colors
                                                    .red,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                            fontSize:
                                                17,
                                          ),
                                        ),
                                        Text(
                                          iptal
                                              ? 'İPTAL'
                                              : 'GİDER',
                                          style:
                                              TextStyle(
                                            color: iptal
                                                ? Colors
                                                    .grey
                                                : Colors
                                                    .red,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                            fontSize:
                                                11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    const Icon(
                                      Icons
                                          .chevron_right,
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
      ),
    );
  }
}