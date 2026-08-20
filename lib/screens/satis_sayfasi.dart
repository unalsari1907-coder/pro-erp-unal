// lib/screens/satis_sayfasi.dart

import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/belge_alt_toplam_cubugu.dart';
import '../widgets/belge_stok_arama_karti.dart';
import '../widgets/logo_klasik_belge_satiri.dart';

import '../models/stok_model.dart';
import '../services/supabase_service.dart';
import '../services/satis_taslak_service.dart';
import '../services/yetki_service.dart';
import '../widgets/cari_sec_dialog.dart';

class SatisSayfasi extends StatefulWidget {
  final StokModel? baslangicStok;

  const SatisSayfasi({
    super.key,
    this.baslangicStok,
  });

  @override
  State<SatisSayfasi> createState() => _SatisSayfasiState();
}

class _SatisSayfasiState extends State<SatisSayfasi> {
  final _aramaController = TextEditingController();
  final _barkodController = TextEditingController();
  final _faturaNoController = TextEditingController();
  final _belgeNoController = TextEditingController();
  final _barkodFocus = FocusNode();

  Timer? _aramaTimer;

  bool _yukleniyor = true;
  bool _araniyor = false;
  bool _kaydediliyor = false;

  List<StokModel> _urunler = [];
  List<Map<String, dynamic>> _cariler = [];
  List<Map<String, dynamic>> _depolar = [];
  List<Map<String, dynamic>> _kasalar = [];
  final List<Map<String, dynamic>> _sepet = [];

  int? _cariId;
  int? _depoId;
  int? _kasaId;

  String _odemeTipi = 'Nakit';
  String _fiyatTipi = 'PERAKENDE';
  int _aktifPanel = 0;

  @override
  void initState() {
    super.initState();
    _ilkVerileriYukle();
  }

  @override
  void dispose() {
    _aramaTimer?.cancel();
    _aramaController.dispose();
    _barkodController.dispose();
    _faturaNoController.dispose();
    _belgeNoController.dispose();
    _barkodFocus.dispose();
    super.dispose();
  }

  bool get _irsaliyeAktarModu {
    return _sepet.any(
      (item) => item['irsaliye_detay_id'] != null,
    );
  }

  bool get _veresiyeMi {
    final deger = _odemeTipi.toLowerCase().trim();
    return deger == 'veresiye' || deger == 'hesap';
  }

  double _sayi(dynamic deger) {
    return double.tryParse(
          deger.toString().replaceAll(',', '.'),
        ) ??
        0.0;
  }

  String _para(dynamic deger) {
    return '${_sayi(deger).toStringAsFixed(2)} ₺';
  }

  Future<void> _ilkVerileriYukle() async {
    if (!mounted) return;

    setState(() => _yukleniyor = true);

    try {
      final sonuclar = await Future.wait([
        SupabaseService.getCariler(),
        SupabaseService.supabase
            .from('depolar')
            .select('depo_id, depo_adi')
            .order('depo_adi'),
        SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi, kasa_tipi')
            .order('kasa_adi'),
      ]);

      final cariler =
          List<Map<String, dynamic>>.from(sonuclar[0] as List);
      final depolar =
          List<Map<String, dynamic>>.from(sonuclar[1] as List);
      final kasalar =
          List<Map<String, dynamic>>.from(sonuclar[2] as List);

      int? varsayilanCari;

      for (final cari in cariler) {
        final unvan =
            cari['unvan']?.toString().toUpperCase() ?? '';

        if (unvan.contains('PERAKENDE')) {
          varsayilanCari =
              int.tryParse(cari['cari_id'].toString());
          break;
        }
      }

      varsayilanCari ??= cariler.isEmpty
          ? null
          : int.tryParse(cariler.first['cari_id'].toString());

      if (!mounted) return;

      setState(() {
        _cariler = cariler;
        _depolar = depolar;
        _kasalar = kasalar;

        _cariId = varsayilanCari;
        Map<String, dynamic>? merkezDepo;
        for (final depo in depolar) {
          final ad = depo['depo_adi']?.toString().trim().toUpperCase() ?? '';
          if (ad.contains('MERKEZ')) {
            merkezDepo = depo;
            break;
          }
        }
        final varsayilanDepo = merkezDepo ?? (depolar.isEmpty ? null : depolar.first);
        _depoId = varsayilanDepo == null
            ? null
            : int.tryParse(varsayilanDepo['depo_id'].toString());
        _kasaId = kasalar.isEmpty
            ? null
            : int.tryParse(kasalar.first['kasa_id'].toString());

        _yukleniyor = false;
      });

      if (_sepet.isEmpty && mounted) {
        if (widget.baslangicStok != null) {
          SatisTaslakService.ekle(widget.baslangicStok!);
        }
        for (final stok in SatisTaslakService.stoklar) {
          _sepeteEkle(stok);
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _barkodFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _yukleniyor = false);
      _mesaj('Veriler yüklenemedi: $e', Colors.red);
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
          setState(() => _urunler = []);
          return;
        }

        setState(() => _araniyor = true);

        final sonuc = await SupabaseService.stoklariGetir(
          aramaMetni: arama,
        );

        if (!mounted) return;

        setState(() {
          _urunler = sonuc;
          _araniyor = false;
        });
      },
    );
  }

  Future<void> _barkodAra(String barkod) async {
    final deger = barkod.trim();
    if (deger.isEmpty) return;

    setState(() => _araniyor = true);

    try {
      final sonuc = await SupabaseService.stoklariGetir(
        aramaMetni: deger,
      );

      if (!mounted) return;

      if (sonuc.isEmpty) {
        _mesaj('Barkoda ait ürün bulunamadı.', Colors.orange);
      } else {
        _sepeteEkle(sonuc.first);
      }
    } finally {
      if (mounted) {
        setState(() => _araniyor = false);
        _barkodController.clear();
        _barkodFocus.requestFocus();
      }
    }
  }

  double _varsayilanFiyat(StokModel stok) {
    return _fiyatTipi == 'TOPTAN'
        ? stok.satisFiyatiToptan
        : stok.satisFiyatiPerakende;
  }

  void _sepeteEkle(StokModel stok) {
    if (_irsaliyeAktarModu) {
      _mesaj(
        'İrsaliye aktarımı açıkken manuel ürün eklenemez. '
        'Manuel satış için önce sepeti temizleyin.',
        Colors.orange,
      );
      return;
    }

    if (stok.stokMiktari <= 0) {
      _mesaj('Bu ürünün stoğu yok.', Colors.red);
      return;
    }

    final index = _sepet.indexWhere(
      (item) => item['stok_id'] == stok.stokId,
    );

    setState(() {
      if (index >= 0) {
        final mevcut =
            int.tryParse(_sepet[index]['miktar'].toString()) ?? 1;

        if (mevcut >= stok.stokMiktari) {
          _mesaj(
            'Sepet miktarı mevcut stoğu aşamaz.',
            Colors.orange,
          );
          return;
        }

        _sepet[index]['miktar'] = mevcut + 1;
      } else {
        _sepet.add({
          'stok': stok,
          'stok_id': stok.stokId,
          'miktar': 1,
          'birim_fiyat': _varsayilanFiyat(stok),
          'indirim': 0.0,
          'kdv_orani': stok.kdv.round(),
        });
      }

      _aktifPanel = 1;
      _aramaController.clear();
      _urunler = [];
    });
  }

  Future<void> _satirDuzenle(int index) async {
    final item = _sepet[index];
    final stok = item['stok'] as StokModel;

    final irsaliyedenMi =
        item['irsaliye_detay_id'] != null;

    final azamiMiktar = irsaliyedenMi
        ? _sayi(item['kalan_miktar'])
        : stok.stokMiktari;

    final miktarController = TextEditingController(
      text: item['miktar'].toString(),
    );
    final fiyatController = TextEditingController(
      text: _sayi(item['birim_fiyat']).toStringAsFixed(2),
    );
    final indirimController = TextEditingController(
      text: _sayi(item['indirim']).toStringAsFixed(2),
    );

    int kdv =
        int.tryParse(item['kdv_orani'].toString()) ?? 20;

    final sonuc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(stok.urunAdi),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      irsaliyedenMi
                          ? 'Faturalanabilir kalan: '
                              '${azamiMiktar.toStringAsFixed(0)}'
                          : 'Mevcut stok: '
                              '${stok.stokMiktari.toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: miktarController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Miktar',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: fiyatController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Birim Fiyat',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: indirimController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'İndirim %',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                            isExpanded: true,
                      value: [0, 1, 10, 20].contains(kdv)
                          ? kdv
                          : 20,
                      decoration: const InputDecoration(
                        labelText: 'KDV',
                        border: OutlineInputBorder(),
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
                        setDialogState(() => kdv = deger);
                      },
                    ),
                  ],
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
                        'miktar':
                            int.tryParse(miktarController.text) ?? 0,
                        'birim_fiyat': _sayi(fiyatController.text),
                        'indirim': _sayi(indirimController.text),
                        'kdv_orani': kdv,
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

    if (sonuc == null) return;

    final miktar = sonuc['miktar'] as int;
    final fiyat = sonuc['birim_fiyat'] as double;
    final indirim = sonuc['indirim'] as double;

    if (miktar <= 0) {
      _mesaj('Miktar sıfırdan büyük olmalıdır.', Colors.orange);
      return;
    }

    if (miktar > azamiMiktar) {
      _mesaj(
        irsaliyedenMi
            ? 'Miktar irsaliyedeki faturalanabilir kalan miktarı aşamaz.'
            : 'Miktar mevcut stoğu aşamaz.',
        Colors.orange,
      );
      return;
    }

    if (fiyat < 0) {
      _mesaj('Fiyat negatif olamaz.', Colors.orange);
      return;
    }

    if (indirim < 0 || indirim > 100) {
      _mesaj('İndirim 0 ile 100 arasında olmalıdır.', Colors.orange);
      return;
    }

    setState(() {
      _sepet[index].addAll(sonuc);
    });
  }

  double _satirBrut(Map<String, dynamic> item) {
    return _sayi(item['miktar']) *
        _sayi(item['birim_fiyat']);
  }

  double _satirIndirim(Map<String, dynamic> item) {
    return _satirBrut(item) *
        _sayi(item['indirim']) /
        100;
  }

  double _satirMatrah(Map<String, dynamic> item) {
    return _satirBrut(item) - _satirIndirim(item);
  }

  double _satirKdv(Map<String, dynamic> item) {
    return _satirMatrah(item) *
        _sayi(item['kdv_orani']) /
        100;
  }

  double _satirToplam(Map<String, dynamic> item) {
    return _satirMatrah(item) + _satirKdv(item);
  }

  double get _araToplam {
    return _sepet.fold<double>(
      0,
      (toplam, item) => toplam + _satirBrut(item),
    );
  }

  double get _toplamIndirim {
    return _sepet.fold<double>(
      0,
      (toplam, item) => toplam + _satirIndirim(item),
    );
  }

  double get _toplamKdv {
    return _sepet.fold<double>(
      0,
      (toplam, item) => toplam + _satirKdv(item),
    );
  }

  double get _genelToplam {
    return _araToplam - _toplamIndirim + _toplamKdv;
  }

  int get _toplamMiktar {
    return _sepet.fold<int>(
      0,
      (toplam, item) =>
          toplam +
          (int.tryParse(item['miktar'].toString()) ?? 0),
    );
  }

  void _odemeTipiDegisti(String? deger) {
    if (deger == null) return;

    setState(() {
      _odemeTipi = deger;

      if (_veresiyeMi) {
        _kasaId = null;
      } else if (_kasaId == null && _kasalar.isNotEmpty) {
        _kasaId = int.tryParse(
          _kasalar.first['kasa_id'].toString(),
        );
      }
    });
  }

  void _fiyatTipiDegisti(String? deger) {
    if (deger == null) return;

    setState(() {
      _fiyatTipi = deger;

      for (final item in _sepet) {
        if (item['irsaliye_detay_id'] != null) {
          continue;
        }

        final stok = item['stok'] as StokModel;
        item['birim_fiyat'] = _varsayilanFiyat(stok);
      }
    });
  }

  Future<void> _irsaliyeAktar() async {
    if (_cariId == null) {
      _mesaj(
        'Önce cari / müşteri seçin.',
        Colors.orange,
      );
      return;
    }

    if (_depoId == null) {
      _mesaj(
        'Önce depo seçin.',
        Colors.orange,
      );
      return;
    }

    if (_sepet.isNotEmpty && !_irsaliyeAktarModu) {
      _mesaj(
        'İrsaliye aktarmadan önce manuel satış sepetini temizleyin.',
        Colors.orange,
      );
      return;
    }

    const sayfaBoyutu = 50;

    Future<Map<String, dynamic>> sayfaGetir(
      int offset,
    ) async {
      final response =
          await SupabaseService.supabase.rpc(
        'satis_irsaliye_aktar_listesi',
        params: {
          'p_cari_id': _cariId,
          'p_depo_id': _depoId,
          'p_limit': sayfaBoyutu,
          'p_offset': offset,
        },
      );

      if (response is Map) {
        return Map<String, dynamic>.from(
          response,
        );
      }

      return <String, dynamic>{
        'items': <dynamic>[],
        'has_more': false,
      };
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final ilkSayfa = await sayfaGetir(0);

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      final irsaliyeler =
          List<Map<String, dynamic>>.from(
        (ilkSayfa['items'] as List?) ??
            const <dynamic>[],
      );

      bool hasMore =
          ilkSayfa['has_more'] == true;

      if (irsaliyeler.isEmpty) {
        _mesaj(
          'Bu cari ve depoya ait faturalanmamış satış irsaliyesi yok.',
          Colors.orange,
        );
        return;
      }

      final secilenIds = <int>{
        ..._sepet
            .map(
              (e) => int.tryParse(
                e['irsaliye_id']
                        ?.toString() ??
                    '',
              ),
            )
            .whereType<int>(),
      };

      bool dahaFazlaYukleniyor = false;

      final sonuc = await showDialog<Set<int>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              context,
              setDialogState,
            ) {
              Future<void> dahaFazlaYukle() async {
                if (!hasMore ||
                    dahaFazlaYukleniyor) {
                  return;
                }

                setDialogState(() {
                  dahaFazlaYukleniyor = true;
                });

                try {
                  final yeniSayfa =
                      await sayfaGetir(
                    irsaliyeler.length,
                  );

                  final yeniKayitlar =
                      List<Map<String, dynamic>>.from(
                    (yeniSayfa['items'] as List?) ??
                        const <dynamic>[],
                  );

                  setDialogState(() {
                    irsaliyeler.addAll(
                      yeniKayitlar,
                    );
                    hasMore =
                        yeniSayfa['has_more'] ==
                            true;
                    dahaFazlaYukleniyor =
                        false;
                  });
                } catch (e) {
                  setDialogState(() {
                    dahaFazlaYukleniyor =
                        false;
                  });

                  if (mounted) {
                    _mesaj(
                      'İrsaliye listesi devamı yüklenemedi: $e',
                      Colors.red,
                    );
                  }
                }
              }

              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Faturalanmamış İrsaliyeleri Aktar',
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 780,
                  height: 560,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue
                              .withOpacity(0.06),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Liste sayfa sayfa yüklenir. '
                          'Yalnızca seçilen cari + depo için '
                          'ONAYLANDI ve kalan miktarı olan irsaliyeler gelir.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                secilenIds
                                  ..clear()
                                  ..addAll(
                                    irsaliyeler.map(
                                      (e) => int.parse(
                                        e['irsaliye_id']
                                            .toString(),
                                      ),
                                    ),
                                  );
                              });
                            },
                            icon: const Icon(
                              Icons.select_all_rounded,
                            ),
                            label:
                                const Text('Tümünü Seç'),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(
                                secilenIds.clear,
                              );
                            },
                            icon: const Icon(
                              Icons.deselect_rounded,
                            ),
                            label: const Text(
                              'Seçimi Kaldır',
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${secilenIds.length} seçili',
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          itemCount:
                              irsaliyeler.length +
                              (hasMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const Divider(
                            height: 1,
                          ),
                          itemBuilder:
                              (context, index) {
                            if (index ==
                                irsaliyeler.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets
                                        .all(12),
                                child: Center(
                                  child:
                                      OutlinedButton.icon(
                                    onPressed:
                                        dahaFazlaYukleniyor
                                            ? null
                                            : dahaFazlaYukle,
                                    icon:
                                        dahaFazlaYukleniyor
                                            ? const SizedBox(
                                                width:
                                                    16,
                                                height:
                                                    16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth:
                                                      2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons
                                                    .expand_more_rounded,
                                              ),
                                    label: Text(
                                      dahaFazlaYukleniyor
                                          ? 'Yükleniyor...'
                                          : 'Daha Fazla Göster',
                                    ),
                                  ),
                                ),
                              );
                            }

                            final irsaliye =
                                irsaliyeler[index];

                            final id =
                                int.parse(
                              irsaliye[
                                      'irsaliye_id']
                                  .toString(),
                            );

                            return CheckboxListTile(
                              value:
                                  secilenIds.contains(
                                id,
                              ),
                              onChanged: (deger) {
                                setDialogState(() {
                                  if (deger ==
                                      true) {
                                    secilenIds
                                        .add(id);
                                  } else {
                                    secilenIds
                                        .remove(id);
                                  }
                                });
                              },
                              secondary:
                                  const CircleAvatar(
                                child: Icon(
                                  Icons
                                      .local_shipping_rounded,
                                ),
                              ),
                              title: Text(
                                irsaliye[
                                            'irsaliye_no']
                                        ?.toString() ??
                                    '-',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${_tarihKisa(irsaliye['tarih'])} • '
                                '${irsaliye['kalem_sayisi'] ?? 0} Kalem • '
                                '${_sayi(irsaliye['kalan_miktar']).toStringAsFixed(0)} Adet Kalan',
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
                      Navigator.pop(
                        dialogContext,
                      );
                    },
                    child:
                        const Text('Vazgeç'),
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        secilenIds.isEmpty
                            ? null
                            : () {
                                Navigator.pop(
                                  dialogContext,
                                  Set<int>.from(
                                    secilenIds,
                                  ),
                                );
                              },
                    icon: const Icon(
                      Icons.download_rounded,
                    ),
                    label:
                        const Text('Sepete Aktar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (sonuc == null || sonuc.isEmpty) {
        return;
      }

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final detayResponse =
          await SupabaseService.supabase
              .from('satis_irsaliye_detay')
              .select(
                'detay_id, irsaliye_id, stok_id, miktar, '
                'faturalanan_miktar, kalan_miktar, '
                'birim_fiyat, indirim_orani, kdv_orani',
              )
              .inFilter(
                'irsaliye_id',
                sonuc.toList(),
              )
              .gt('kalan_miktar', 0)
              .neq('durum', 'IPTAL')
              .order('irsaliye_id')
              .order('detay_id');

      final secilenDetaylar =
          List<Map<String, dynamic>>.from(
        detayResponse,
      );

      final stokIds = secilenDetaylar
          .map(
            (d) => int.tryParse(
              d['stok_id']?.toString() ?? '',
            ),
          )
          .whereType<int>()
          .toSet()
          .toList();

      final stokResponse = stokIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await SupabaseService.supabase
                  .from('stoklar')
                  .select()
                  .inFilter(
                    'stok_id',
                    stokIds,
                  ),
            );

      final stokMap =
          <int, Map<String, dynamic>>{
        for (final stok in stokResponse)
          if (int.tryParse(
                stok['stok_id']?.toString() ?? '',
              ) !=
              null)
            int.parse(
              stok['stok_id'].toString(),
            ): stok,
      };

      final irsaliyeNoMap =
          <int, String>{
        for (final irsaliye in irsaliyeler)
          if (int.tryParse(
                irsaliye['irsaliye_id']
                        ?.toString() ??
                    '',
              ) !=
              null)
            int.parse(
              irsaliye['irsaliye_id']
                  .toString(),
            ): irsaliye['irsaliye_no']
                    ?.toString() ??
                '-',
      };

      final mevcutDetayMap =
          <int, Map<String, dynamic>>{
        for (final item in _sepet)
          if (item['irsaliye_detay_id'] !=
              null)
            int.parse(
              item['irsaliye_detay_id']
                  .toString(),
            ): item,
      };

      final yeniSepet =
          <Map<String, dynamic>>[];

      for (final detay in secilenDetaylar) {
        final detayId = int.tryParse(
              detay['detay_id']
                      ?.toString() ??
                  '',
            ) ??
            0;

        final irsaliyeId =
            int.tryParse(
                  detay['irsaliye_id']
                          ?.toString() ??
                      '',
                ) ??
                0;

        final stokId = int.tryParse(
              detay['stok_id']?.toString() ?? '',
            ) ??
            0;

        final stokJson =
            stokMap[stokId];

        if (detayId <= 0 ||
            irsaliyeId <= 0 ||
            stokId <= 0 ||
            stokJson == null) {
          continue;
        }

        final stok = StokModel.fromJson(
          stokJson,
        );

        final kalan =
            _sayi(detay['kalan_miktar']);

        if (kalan <= 0) {
          continue;
        }

        final mevcut =
            mevcutDetayMap[detayId];

        final mevcutMiktar =
            mevcut == null
                ? kalan.round()
                : int.tryParse(
                      mevcut['miktar']
                          .toString(),
                    ) ??
                    kalan.round();

        yeniSepet.add({
          'stok': stok,
          'stok_id': stok.stokId,
          'miktar': mevcutMiktar.clamp(
            1,
            kalan.round(),
          ),
          'birim_fiyat': mevcut == null
              ? _sayi(
                  detay['birim_fiyat'],
                )
              : _sayi(
                  mevcut['birim_fiyat'],
                ),
          'indirim': mevcut == null
              ? _sayi(
                  detay['indirim_orani'],
                )
              : _sayi(
                  mevcut['indirim'],
                ),
          'kdv_orani': mevcut == null
              ? _sayi(
                  detay['kdv_orani'],
                ).round()
              : int.tryParse(
                    mevcut['kdv_orani']
                        .toString(),
                  ) ??
                  20,
          'irsaliye_id': irsaliyeId,
          'irsaliye_detay_id': detayId,
          'kaynak_irsaliye_no':
              irsaliyeNoMap[irsaliyeId] ??
                  '-',
          'kalan_miktar': kalan,
        });
      }

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      setState(() {
        _sepet
          ..clear()
          ..addAll(yeniSepet);

        _aktifPanel = 1;
      });

      _mesaj(
        '${sonuc.length} irsaliye faturaya aktarıldı.',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      _mesaj(
        'İrsaliye aktarım hatası: $e',
        Colors.red,
      );
    }
  }

  String _tarihKisa(dynamic value) {
    final raw = value?.toString() ?? '';
    final tarih = DateTime.tryParse(raw)?.toLocal();

    if (tarih == null) return '-';

    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year}';
  }

  Future<void> _satisiKaydet() async {
    if (_sepet.isEmpty) {
      _mesaj('Satış için ürün ekleyin.', Colors.orange);
      return;
    }

    if (_cariId == null) {
      _mesaj('Cari seçin.', Colors.orange);
      return;
    }

    if (_depoId == null) {
      _mesaj('Depo seçin.', Colors.orange);
      return;
    }

    if (!_veresiyeMi && _kasaId == null) {
      _mesaj('Kasa seçin.', Colors.orange);
      return;
    }

    for (final item in _sepet) {
      final stok = item['stok'] as StokModel;
      final miktar =
          int.tryParse(item['miktar'].toString()) ?? 0;
      final fiyat = _sayi(item['birim_fiyat']);
      final indirim = _sayi(item['indirim']);
      final netBirimFiyat =
          fiyat * (1 - indirim / 100);

      final irsaliyedenMi =
          item['irsaliye_detay_id'] != null;

      final azamiMiktar = irsaliyedenMi
          ? _sayi(item['kalan_miktar'])
          : stok.stokMiktari;

      if (miktar <= 0 || miktar > azamiMiktar) {
        _mesaj(
          irsaliyedenMi
              ? '${stok.urunAdi}: Miktar irsaliyedeki kalan miktarı aşamaz.'
              : '${stok.urunAdi}: Miktar hatalı.',
          Colors.red,
        );
        return;
      }

      if (netBirimFiyat < stok.alisFiyati) {
        _mesaj(
          '${stok.urunAdi}: Alış fiyatının altında '
          'satış yapılamaz.',
          Colors.red,
        );
        return;
      }
    }

    // Veresiye satışlarda cari risk limitini kontrol et.
    if (_veresiyeMi && _cariId != null) {
      Map<String, dynamic>? cari;
      for (final item in _cariler) {
        final id = int.tryParse(item['cari_id']?.toString() ?? '');
        if (id == _cariId) {
          cari = item;
          break;
        }
      }

      if (cari != null) {
        final seciliCari = cari;
        final riskLimiti = _sayi(seciliCari['risk_limiti']);
        final mevcutBakiye = _sayi(seciliCari['bakiye']);
        final yeniBakiye = mevcutBakiye + _genelToplam;

        if (riskLimiti > 0 && yeniBakiye > riskLimiti) {
          final devam = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Cari Risk Limiti Aşılıyor'),
              content: Text(
                'Cari: ${seciliCari['unvan'] ?? '-'}\n'
                'Mevcut Bakiye: ${mevcutBakiye.toStringAsFixed(2)} ₺\n'
                'Bu Satış: ${_genelToplam.toStringAsFixed(2)} ₺\n'
                'Yeni Bakiye: ${yeniBakiye.toStringAsFixed(2)} ₺\n'
                'Risk Limiti: ${riskLimiti.toStringAsFixed(2)} ₺\n\n'
                'Yönetici onayı olmadan devam edilmemesi önerilir.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Yine de Devam Et'),
                ),
              ],
            ),
          );

          if (devam != true) return;
        }
      }
    }

    setState(() => _kaydediliyor = true);

    try {
      // Fatura numarası kullanıcı tarafından girilmediyse
      // kaydetmeden hemen önce otomatik üret.
      if (_faturaNoController.text.trim().isEmpty) {
        final yeniNo =
            await SupabaseService.yeniBelgeNoGetir(
          belgeTipi: 'SATIS',
        );

        if (!mounted) return;

        _faturaNoController.text = yeniNo;
      }

      final detaylar = _sepet.map((item) {
        return <String, dynamic>{
          'stok_id': item['stok_id'],
          'miktar':
              int.tryParse(item['miktar'].toString()) ?? 1,
          'birim_fiyat': _sayi(item['birim_fiyat']),
          'indirim': _sayi(item['indirim']),
          'kdv_orani':
              int.tryParse(item['kdv_orani'].toString()) ?? 0,
          if (item['irsaliye_id'] != null)
            'irsaliye_id': item['irsaliye_id'],
          if (item['irsaliye_detay_id'] != null)
            'irsaliye_detay_id':
                item['irsaliye_detay_id'],
        };
      }).toList();

      final dynamic satisId;

      if (_irsaliyeAktarModu) {
        satisId =
            await SupabaseService.supabase.rpc(
          'satis_fatura_irsaliye_aktar',
          params: {
            'p_cari_id': _cariId,
            'p_kasa_id':
                _veresiyeMi ? null : _kasaId,
            'p_odeme_tipi': _odemeTipi,
            'p_fatura_no':
                _faturaNoController.text.trim(),
            'p_belge_no':
                _belgeNoController.text.trim(),
            'p_depo_id': _depoId,
            'p_fiyat_tipi': _fiyatTipi,
            'p_kullanici': YetkiService.aktifKullanici,
            'p_detaylar': detaylar,
          },
        );
      } else {
        satisId =
            await SupabaseService.satisYap(
          cariId: _cariId!,
          kasaId:
              _veresiyeMi ? null : _kasaId,
          odemeTipi: _odemeTipi,
          faturaNo:
              _faturaNoController.text.trim(),
          belgeNo:
              _belgeNoController.text.trim(),
          depoId: _depoId!,
          fiyatTipi: _fiyatTipi,
          kullanici: YetkiService.aktifKullanici,
          sepet: detaylar,
        );
      }

      if (!mounted) return;

      _mesaj(
        'Satış başarıyla kaydedildi. Satış ID: $satisId',
        Colors.green,
      );

      _formuTemizle();
      await _ilkVerileriYukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj(
        'Satış kayıt hatası: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _kaydediliyor = false);
      }
    }
  }

  void _formuTemizle() {
    SatisTaslakService.temizle();
    setState(() {
      _sepet.clear();
      _aramaController.clear();
      _barkodController.clear();
      _faturaNoController.clear();
      _belgeNoController.clear();
      _odemeTipi = 'Nakit';
      _fiyatTipi = 'PERAKENDE';
      _aktifPanel = 0;

      if (_kasalar.isNotEmpty) {
        _kasaId = int.tryParse(
          _kasalar.first['kasa_id'].toString(),
        );
      }
    });

    _barkodFocus.requestFocus();
  }

  String _seciliCariAdi() {
    if (_cariId == null) return 'Cari seçin';

    for (final cari in _cariler) {
      final id = int.tryParse(cari['cari_id']?.toString() ?? '');
      if (id == _cariId) {
        final unvan = cari['unvan']?.toString().trim() ?? '';
        return unvan.isEmpty ? 'Cari seçin' : unvan;
      }
    }

    return 'Cari seçin';
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: renk,
      ),
    );
  }

  Widget _ustBilgiler() {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 300,
              child: InkWell(
                onTap: _irsaliyeAktarModu
                    ? null
                    : () async {
                        final secilen = await CariSecDialog.ac(
                          context: context,
                          cariler: _cariler,
                          seciliCariId: _cariId,
                          baslik: 'Satış Cari / Müşteri Seç',
                          aramaIpucu: 'Cari ünvanı ara...',
                        );

                        if (secilen == null || !mounted) return;

                        setState(() {
                          _cariId = secilen;
                        });
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Cari / Müşteri',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    border: const OutlineInputBorder(),
                    enabled: !_irsaliyeAktarModu,
                  ),
                  child: Text(
                    _seciliCariAdi(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<int>(
                            isExpanded: true,
                value: _depoId,
                decoration: const InputDecoration(
                  labelText: 'Depo',
                  border: OutlineInputBorder(),
                ),
                items: _depolar.map((depo) {
                  return DropdownMenuItem<int>(
                    value: int.tryParse(
                      depo['depo_id'].toString(),
                    ),
                    child: Text(
                      depo['depo_adi']?.toString() ?? '',
                    ),
                  );
                }).toList(),
                onChanged: _irsaliyeAktarModu
                    ? null
                    : (deger) {
                        setState(
                          () => _depoId = deger,
                        );
                      },
              ),
            ),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _kaydediliyor
                    ? null
                    : _irsaliyeAktar,
                icon: const Icon(
                  Icons.local_shipping_rounded,
                ),
                label: Text(
                  _irsaliyeAktarModu
                      ? 'İrsaliyeleri Değiştir'
                      : 'İrsaliye Aktar',
                ),
              ),
            ),
            SizedBox(
              width: 175,
              child: DropdownButtonFormField<String>(
                            isExpanded: true,
                value: _odemeTipi,
                decoration: const InputDecoration(
                  labelText: 'Ödeme Tipi',
                  border: OutlineInputBorder(),
                ),
                items: const [
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
                  DropdownMenuItem(
                    value: 'Veresiye',
                    child: Text('Veresiye'),
                  ),
                ],
                onChanged: _odemeTipiDegisti,
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<int>(
                            isExpanded: true,
                value: _veresiyeMi ? null : _kasaId,
                decoration: InputDecoration(
                  labelText: 'Kasa / Banka',
                  hintText: _veresiyeMi
                      ? 'Veresiyede kullanılmaz'
                      : null,
                  border: const OutlineInputBorder(),
                ),
                items: _kasalar.map((kasa) {
                  return DropdownMenuItem<int>(
                    value: int.tryParse(
                      kasa['kasa_id'].toString(),
                    ),
                    child: Text(
                      kasa['kasa_adi']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _veresiyeMi
                    ? null
                    : (deger) {
                        setState(() => _kasaId = deger);
                      },
              ),
            ),
            SizedBox(
              width: 155,
              child: DropdownButtonFormField<String>(
                            isExpanded: true,
                value: _fiyatTipi,
                decoration: const InputDecoration(
                  labelText: 'Fiyat Tipi',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'PERAKENDE',
                    child: Text('Perakende'),
                  ),
                  DropdownMenuItem(
                    value: 'TOPTAN',
                    child: Text('Toptan'),
                  ),
                ],
                onChanged: _fiyatTipiDegisti,
              ),
            ),
            SizedBox(
              width: 170,
              child: TextField(
                controller: _faturaNoController,
                decoration: const InputDecoration(
                  labelText: 'Fatura No',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 170,
              child: TextField(
                controller: _belgeNoController,
                decoration: const InputDecoration(
                  labelText: 'Belge No',
                  border: OutlineInputBorder(),
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
              controller: _barkodController,
              focusNode: _barkodFocus,
              decoration: const InputDecoration(
                hintText: 'Barkod okutun...',
                prefixIcon: Icon(Icons.qr_code_scanner),
                border: OutlineInputBorder(),
              ),
              onSubmitted: _barkodAra,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _aramaController,
              decoration: const InputDecoration(
                hintText:
                    'Ürün adı, üretici kodu, OEM, barkod, marka, araç, raf...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _aramaYap,
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
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _urunler.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final stok = _urunler[index];

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
            'Sepet boş.',
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
        alis: false,
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
            setState(() {
              _sepet.removeAt(index);
              if (_sepet.isEmpty) _aktifPanel = 0;
            });
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
        OutlinedButton.icon(
          onPressed: _kaydediliyor ? null : _formuTemizle,
          icon: const Icon(Icons.delete_sweep),
          label: const Text('Temizle'),
        ),
        ElevatedButton.icon(
          onPressed: _kaydediliyor ? null : _satisiKaydet,
          icon: _kaydediliyor
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle),
          label: Text(
            _kaydediliyor
                ? 'Kaydediliyor...'
                : _irsaliyeAktarModu
                    ? 'İrsaliyeleri Faturala'
                    : 'Satışı Tamamla',
          ),
        ),
      ],
    );
  }

  Widget _kurumsalFaturaBasligi() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 50,
            height: 50,
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
                Text('ÜNAL YEDEK PARÇA', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Text('Kurumsal ERP • Resmi Belge Girişi'),
              ],
            ),
          ),
          Text(
            'SATIŞ FATURASI',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900),
          ),
        ],
      ),
    );
  }

  Widget _darDuzen() {
    return Column(
      children: [
        _kurumsalFaturaBasligi(),
        Card(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 2),
          elevation: 0,
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            leading: const Icon(Icons.tune_rounded),
            title: const Text(
              'Belge Bilgileri',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Cari, depo, ödeme, kasa ve belge no',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 370),
                child: SingleChildScrollView(child: _ustBilgiler()),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [
                const ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.search),
                  label: Text('Ürün Ara'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: const Icon(Icons.shopping_cart),
                  label: Text('Sepet (${_sepet.length})'),
                ),
              ],
              selected: {_aktifPanel},
              onSelectionChanged: (secim) {
                setState(() => _aktifPanel = secim.first);
              },
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _aktifPanel,
            children: [
              _aramaPaneli(),
              _sepetPaneli(),
            ],
          ),
        ),
        _altBolum(),
      ],
    );
  }

  Widget _genisDuzen() {
    return Column(
      children: [
        _kurumsalFaturaBasligi(),
        _ustBilgiler(),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 390,
                child: _aramaPaneli(),
              ),
              Expanded(child: _sepetPaneli()),
            ],
          ),
        ),
        _altBolum(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'SATIŞ FATURASI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!SatisTaslakService.bos)
            TextButton.icon(
              onPressed: _kaydediliyor ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Stok Kartlarına Dön'),
            ),
          IconButton(
            tooltip: 'Yenile',
            onPressed:
                _kaydediliyor ? null : _ilkVerileriYukle,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _yukleniyor
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return constraints.maxWidth >= 1150
                      ? _genisDuzen()
                      : _darDuzen();
                },
              ),
            ),
    );
  }
}
