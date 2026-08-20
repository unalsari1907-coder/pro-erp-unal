// lib/screens/satin_alma/satin_alma_sayfasi.dart

import 'package:flutter/material.dart';

import '../../widgets/belge_alt_toplam_cubugu.dart';


import '../../models/stok_model.dart';
import '../../services/supabase_service.dart';
import '../../services/yetki_service.dart';

import 'widgets/alis_footer.dart';
import 'widgets/alis_grid.dart';
import 'widgets/alis_header.dart';
import 'widgets/alis_toplam.dart';
import 'widgets/alis_urun_arama.dart';

class SatinAlmaSayfasi extends StatefulWidget {
  final bool kayitSonrasiKapat;

  const SatinAlmaSayfasi({
    super.key,
    this.kayitSonrasiKapat = false,
  });

  @override
  State<SatinAlmaSayfasi> createState() => _SatinAlmaSayfasiState();
}

class _SatinAlmaSayfasiState extends State<SatinAlmaSayfasi> {
  final TextEditingController _faturaNoController =
      TextEditingController();

  final TextEditingController _tarihController =
      TextEditingController();

  final List<Map<String, dynamic>> _sepet = [];

  List<Map<String, dynamic>> _tedarikciler = [];
  List<Map<String, dynamic>> _depolar = [];
  List<Map<String, dynamic>> _kasalar = [];

  int? _secilenTedarikciId;
  int? _secilenDepoId;
  int? _secilenKasaId;

  String _odemeTipi = 'Veresiye';

  bool _yukleniyor = true;
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();

    final simdi = DateTime.now();

    _tarihController.text =
        '${simdi.day.toString().padLeft(2, '0')}.'
        '${simdi.month.toString().padLeft(2, '0')}.'
        '${simdi.year}';

    _ilkVerileriYukle();
    _yeniFaturaNoGetir();
  }

  @override
  void dispose() {
    _faturaNoController.dispose();
    _tarihController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------
  // YENİ FATURA NO
  // ------------------------------------------------------

  Future<void> _yeniFaturaNoGetir() async {
    try {
      final yeniNo =
          await SupabaseService.yeniBelgeNoGetir(
        belgeTipi: 'ALIS',
      );

      if (!mounted) return;

      _faturaNoController.text = yeniNo;
    } catch (e) {
      if (!mounted) return;

      _mesaj(
        'Alış fatura numarası alınamadı: $e',
        Colors.red,
      );
    }
  }

  // ------------------------------------------------------
  // İLK VERİLER
  // ------------------------------------------------------

  Future<void> _ilkVerileriYukle() async {
    if (!mounted) return;

    setState(() {
      _yukleniyor = true;
    });

    try {
      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from('cariler')
            .select('cari_id, unvan, cari_tipi, aktif')
            .eq('aktif', true)
            .order('unvan'),
        SupabaseService.supabase
            .from('depolar')
            .select('depo_id, depo_adi')
            .order('depo_adi'),
        SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi, kasa_tipi')
            .order('kasa_adi'),
      ]);

      if (!mounted) return;

      final tumCariler =
          List<Map<String, dynamic>>.from(sonuclar[0] as List);

      final tedarikciler = tumCariler.where((cari) {
        final tip =
            cari['cari_tipi']?.toString().toUpperCase() ?? '';

        return tip.contains('TEDARIK') ||
            tip.contains('TEDARİK');
      }).toList();

      final depolar =
          List<Map<String, dynamic>>.from(sonuclar[1] as List);

      final kasalar =
          List<Map<String, dynamic>>.from(sonuclar[2] as List);

      setState(() {
        _tedarikciler =
            tedarikciler.isEmpty ? tumCariler : tedarikciler;

        _depolar = depolar;
        _kasalar = kasalar;

        if (_tedarikciler.isNotEmpty) {
          _secilenTedarikciId = int.tryParse(
            _tedarikciler.first['cari_id'].toString(),
          );
        }

        if (_depolar.isNotEmpty) {
          Map<String, dynamic>? merkezDepo;
          for (final depo in _depolar) {
            final ad = depo['depo_adi']?.toString().trim().toUpperCase() ?? '';
            if (ad.contains('MERKEZ')) {
              merkezDepo = depo;
              break;
            }
          }
          final varsayilanDepo = merkezDepo ?? _depolar.first;
          _secilenDepoId = int.tryParse(
            varsayilanDepo['depo_id'].toString(),
          );
        }

        if (_kasalar.isNotEmpty) {
          _secilenKasaId = int.tryParse(
            _kasalar.first['kasa_id'].toString(),
          );
        }

        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      _mesaj(
        'Veriler yüklenemedi: $e',
        Colors.red,
      );
    }
  }

  bool get _irsaliyeAktarModu {
    return _sepet.any(
      (item) => item['irsaliye_detay_id'] != null,
    );
  }

  Set<int> get _aktarilanIrsaliyeIds {
    return _sepet
        .map(
          (item) => int.tryParse(
            item['irsaliye_id']?.toString() ?? '',
          ),
        )
        .whereType<int>()
        .toSet();
  }

  // ------------------------------------------------------
  // SEPET
  // ------------------------------------------------------

  void _sepeteEkle(StokModel stok) {
    if (_irsaliyeAktarModu) {
      _mesaj(
        'İrsaliye aktarımı açıkken manuel ürün eklenemez. '
        'Manuel alış için önce sepeti temizleyin.',
        Colors.orange,
      );
      return;
    }

    final index = _sepet.indexWhere(
      (item) =>
          (item['stok'] as StokModel).stokId == stok.stokId,
    );

    setState(() {
      if (index >= 0) {
        final mevcutMiktar =
            int.tryParse(_sepet[index]['miktar'].toString()) ?? 1;

        _sepet[index]['miktar'] = mevcutMiktar + 1;
      } else {
        _sepet.add({
          'stok': stok,
          'miktar': 1,
          'alisFiyati': stok.alisFiyati,
          'iskonto': 0.0,
          'kdv': stok.kdv,
        });
      }
    });
  }

  void _miktarDegistir(int index, int miktar) {
    if (miktar <= 0) return;

    final item = _sepet[index];

    if (item['irsaliye_detay_id'] != null) {
      final kalan =
          _sayiyaCevir(item['kalan_miktar']);

      if (miktar > kalan) {
        _mesaj(
          'Miktar irsaliyedeki faturalanabilir kalan miktarı aşamaz.',
          Colors.orange,
        );
        return;
      }
    }

    setState(() {
      _sepet[index]['miktar'] = miktar;
    });
  }

  void _fiyatDegistir(int index, double fiyat) {
    setState(() {
      _sepet[index]['alisFiyati'] =
          fiyat < 0 ? 0.0 : fiyat;
    });
  }

  void _iskontoDegistir(int index, double iskonto) {
    setState(() {
      _sepet[index]['iskonto'] =
          iskonto.clamp(0, 100).toDouble();
    });
  }

  void _kdvDegistir(int index, double kdv) {
    setState(() {
      _sepet[index]['kdv'] = kdv;
    });
  }

  void _satirSil(int index) {
    setState(() {
      _sepet.removeAt(index);
    });
  }

  // ------------------------------------------------------
  // HESAPLAMALAR
  // ------------------------------------------------------

  double _sayiyaCevir(dynamic deger) {
    return double.tryParse(
          deger.toString().replaceAll(',', '.'),
        ) ??
        0.0;
  }

  double _brutToplam(Map<String, dynamic> item) {
    final miktar = _sayiyaCevir(item['miktar']);
    final fiyat = _sayiyaCevir(item['alisFiyati']);

    return miktar * fiyat;
  }

  double _iskontoTutari(Map<String, dynamic> item) {
    final brutToplam = _brutToplam(item);
    final iskontoOrani = _sayiyaCevir(item['iskonto']);

    return brutToplam * iskontoOrani / 100;
  }

  double _matrah(Map<String, dynamic> item) {
    return _brutToplam(item) - _iskontoTutari(item);
  }

  double _kdvTutari(Map<String, dynamic> item) {
    final matrah = _matrah(item);
    final kdvOrani = _sayiyaCevir(item['kdv']);

    return matrah * kdvOrani / 100;
  }

  double get _araToplam {
    return _sepet.fold<double>(
      0,
      (toplam, item) => toplam + _brutToplam(item),
    );
  }

  double get _toplamIskonto {
    return _sepet.fold<double>(
      0,
      (toplam, item) => toplam + _iskontoTutari(item),
    );
  }

  double get _toplamKdv {
    return _sepet.fold<double>(
      0,
      (toplam, item) => toplam + _kdvTutari(item),
    );
  }

  double get _genelToplam {
    return _araToplam - _toplamIskonto + _toplamKdv;
  }

  int get _toplamMiktar {
    return _sepet.fold<int>(
      0,
      (toplam, item) =>
          toplam +
          (int.tryParse(item['miktar'].toString()) ?? 0),
    );
  }

  Future<void> _irsaliyeAktar() async {
    if (_secilenTedarikciId == null) {
      _mesaj(
        'Önce tedarikçi / cari seçin.',
        Colors.orange,
      );
      return;
    }

    if (_secilenDepoId == null) {
      _mesaj(
        'Önce depo seçin.',
        Colors.orange,
      );
      return;
    }

    if (_sepet.isNotEmpty && !_irsaliyeAktarModu) {
      _mesaj(
        'İrsaliye aktarmadan önce manuel alış sepetini temizleyin.',
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
        'alis_irsaliye_aktar_listesi',
        params: {
          'p_cari_id':
              _secilenTedarikciId,
          'p_depo_id':
              _secilenDepoId,
          'p_limit':
              sayfaBoyutu,
          'p_offset':
              offset,
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
      final ilkSayfa =
          await sayfaGetir(0);

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
          'Bu tedarikçi ve depoya ait faturalanmamış alış irsaliyesi yok.',
          Colors.orange,
        );
        return;
      }

      final secilenIds = <int>{
        ..._aktarilanIrsaliyeIds,
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
                      Icons.local_shipping_outlined,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Faturalanmamış Alış İrsaliyelerini Aktar',
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
                            const EdgeInsets.all(
                          10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal
                              .withOpacity(0.06),
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: const Text(
                          'Liste sayfa sayfa yüklenir. '
                          'Yalnızca seçilen tedarikçi + depo için '
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
                                      (e) =>
                                          int.parse(
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
                            label: const Text(
                              'Tümünü Seç',
                            ),
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
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child:
                            ListView.separated(
                          itemCount:
                              irsaliyeler.length +
                              (hasMore ? 1 : 0),
                          separatorBuilder:
                              (_, __) {
                            return const Divider(
                              height: 1,
                            );
                          },
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

                            final id = int.parse(
                              irsaliye[
                                      'irsaliye_id']
                                  .toString(),
                            );

                            return CheckboxListTile(
                              value:
                                  secilenIds
                                      .contains(id),
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
                                      .inventory_rounded,
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
                                '${_sayiyaCevir(irsaliye['kalan_miktar']).toStringAsFixed(0)} Adet Kalan',
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
                    label: const Text(
                      'Sepete Aktar',
                    ),
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
              .from('alis_irsaliye_detay')
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
            _sayiyaCevir(
          detay['kalan_miktar'],
        );

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
          'miktar': mevcutMiktar.clamp(
            1,
            kalan.round(),
          ),
          'alisFiyati': mevcut == null
              ? _sayiyaCevir(
                  detay['birim_fiyat'],
                )
              : _sayiyaCevir(
                  mevcut['alisFiyati'],
                ),
          'iskonto': mevcut == null
              ? _sayiyaCevir(
                  detay['indirim_orani'],
                )
              : _sayiyaCevir(
                  mevcut['iskonto'],
                ),
          'kdv': mevcut == null
              ? _sayiyaCevir(
                  detay['kdv_orani'],
                )
              : _sayiyaCevir(
                  mevcut['kdv'],
                ),
          'irsaliye_id':
              irsaliyeId,
          'irsaliye_detay_id':
              detayId,
          'kaynak_irsaliye_no':
              irsaliyeNoMap[irsaliyeId] ??
                  '-',
          'kalan_miktar':
              kalan,
        });
      }

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      setState(() {
        _sepet
          ..clear()
          ..addAll(yeniSepet);
      });

      _mesaj(
        '${sonuc.length} alış irsaliyesi faturaya aktarıldı.',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      _mesaj(
        'Alış irsaliyesi aktarım hatası: $e',
        Colors.red,
      );
    }
  }

  String _tarihKisa(dynamic value) {
    final raw =
        value?.toString() ?? '';

    final tarih =
        DateTime.tryParse(raw)?.toLocal();

    if (tarih == null) {
      return '-';
    }

    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year}';
  }

  Widget _irsaliyeAktarCubugu() {
    final irsaliyeNolari = _sepet
        .map(
          (item) => item['kaynak_irsaliye_no']
              ?.toString(),
        )
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        12,
        6,
        12,
        6,
      ),
      color: Colors.white,
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _kaydediliyor
                ? null
                : _irsaliyeAktar,
            icon: const Icon(
              Icons.local_shipping_outlined,
            ),
            label: Text(
              _irsaliyeAktarModu
                  ? 'İrsaliyeleri Değiştir'
                  : 'İrsaliye Aktar',
            ),
          ),
          if (_irsaliyeAktarModu) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aktarılan İrsaliyeler: '
                '${irsaliyeNolari.join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------
  // KAYDET
  // ------------------------------------------------------

  Future<void> _alisiKaydet() async {
    if (_sepet.isEmpty) {
      _mesaj(
        'Alış kaydı için en az bir ürün ekleyin.',
        Colors.orange,
      );
      return;
    }

    if (_secilenTedarikciId == null) {
      _mesaj(
        'Lütfen bir tedarikçi seçin.',
        Colors.orange,
      );
      return;
    }

    if (_secilenDepoId == null) {
      _mesaj(
        'Lütfen bir depo seçin.',
        Colors.orange,
      );
      return;
    }

    if (_odemeTipi != 'Veresiye' &&
        _secilenKasaId == null) {
      _mesaj(
        'Nakit veya kartlı işlem için kasa seçin.',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _kaydediliyor = true;
    });

    try {
      for (final item in _sepet) {
        if (item['irsaliye_detay_id'] == null) {
          continue;
        }

        final miktar =
            int.tryParse(
                  item['miktar'].toString(),
                ) ??
                0;

        final kalan =
            _sayiyaCevir(
          item['kalan_miktar'],
        );

        if (miktar <= 0 ||
            miktar > kalan) {
          final stok =
              item['stok'] as StokModel;

          _mesaj(
            '${stok.urunAdi}: Miktar irsaliyedeki kalan miktarı aşamaz.',
            Colors.red,
          );
          return;
        }
      }

      final rpcSepet = _sepet.map((item) {
        final stok =
            item['stok'] as StokModel;

        return <String, dynamic>{
          'stok_id': stok.stokId,
          'miktar':
              int.tryParse(
                    item['miktar'].toString(),
                  ) ??
                  1,
          'birim_fiyat':
              _sayiyaCevir(
            item['alisFiyati'],
          ),
          'indirim':
              _sayiyaCevir(
            item['iskonto'],
          ),
          'kdv_orani':
              _sayiyaCevir(
            item['kdv'],
          ).round(),
          if (item['irsaliye_id'] != null)
            'irsaliye_id':
                item['irsaliye_id'],
          if (item['irsaliye_detay_id'] !=
              null)
            'irsaliye_detay_id':
                item['irsaliye_detay_id'],
        };
      }).toList();

      int? alisId;

      if (_irsaliyeAktarModu) {
        final sonuc =
            await SupabaseService.supabase.rpc(
          'alis_fatura_irsaliye_aktar',
          params: {
            'p_cari_id':
                _secilenTedarikciId,
            'p_kasa_id':
                _odemeTipi == 'Veresiye'
                    ? null
                    : _secilenKasaId,
            'p_odeme_tipi':
                _odemeTipi,
            'p_fatura_no':
                _faturaNoController.text
                    .trim(),
            'p_depo_id':
                _secilenDepoId,
            'p_kullanici':
                YetkiService.aktifKullanici,
            'p_detaylar':
                rpcSepet,
          },
        );

        alisId = int.tryParse(
          sonuc?.toString() ?? '',
        );
      } else {
        alisId =
            await SupabaseService.alisYap(
          cariId:
              _secilenTedarikciId!,
          kasaId:
              _odemeTipi == 'Veresiye'
                  ? null
                  : _secilenKasaId,
          odemeTipi:
              _odemeTipi,
          faturaNo:
              _faturaNoController.text
                  .trim(),
          depoId:
              _secilenDepoId!,
          kullanici:
              YetkiService.aktifKullanici,
          sepet:
              rpcSepet,
        );
      }

      if (!mounted) return;

      if (alisId == null) {
        _mesaj(
          'Alış kaydı tamamlanamadı.',
          Colors.red,
        );
        return;
      }

      _mesaj(
        'Alış başarıyla kaydedildi.',
        Colors.green,
      );

      if (widget.kayitSonrasiKapat) {
        Navigator.pop(context, true);
        return;
      }

      _formuTemizle();
      await _yeniFaturaNoGetir();
      await _ilkVerileriYukle();
    } catch (e) {
      if (!mounted) return;

      _mesaj(
        'Alış kayıt hatası: $e',
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

  // ------------------------------------------------------
  // TEMİZLE / İPTAL
  // ------------------------------------------------------

  void _formuTemizle() {
    setState(() {
      _sepet.clear();
      _odemeTipi = 'Veresiye';
    });
  }

  void _iptalEt() {
    if (_sepet.isEmpty) {
      Navigator.maybePop(context);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Satın alma işlemini iptal et',
          ),
          content: const Text(
            'Eklenen bütün alış kalemleri silinecek. '
            'Devam etmek istiyor musunuz?',
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
                Navigator.pop(dialogContext);
                _formuTemizle();
              },
              child: const Text('İptal Et'),
            ),
          ],
        );
      },
    );
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: renk,
      ),
    );
  }

  Widget _kurumsalFaturaBasligi() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
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
            'ALIŞ FATURASI',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------
  // HEADER
  // ------------------------------------------------------

  Widget _header() {
    return AlisHeader(
      faturaNoController: _faturaNoController,
      tarihController: _tarihController,
      tedarikciler: _tedarikciler,
      depolar: _depolar,
      kasalar: _kasalar,
      secilenTedarikciId: _secilenTedarikciId,
      secilenDepoId: _secilenDepoId,
      secilenKasaId: _secilenKasaId,
      odemeTipi: _odemeTipi,
      onTedarikciDegisti: (deger) {
        if (_irsaliyeAktarModu) {
          _mesaj(
            'İrsaliye aktarılmışken tedarikçi değiştirilemez. '
            'Önce sepeti temizleyin.',
            Colors.orange,
          );
          return;
        }

        setState(() {
          _secilenTedarikciId = deger;
        });
      },
      onDepoDegisti: (deger) {
        if (_irsaliyeAktarModu) {
          _mesaj(
            'İrsaliye aktarılmışken depo değiştirilemez. '
            'Önce sepeti temizleyin.',
            Colors.orange,
          );
          return;
        }

        setState(() {
          _secilenDepoId = deger;
        });
      },
      onKasaDegisti: (deger) {
        setState(() {
          _secilenKasaId = deger;
        });
      },
      onOdemeTipiDegisti: (deger) {
        if (deger == null) return;

        setState(() {
          _odemeTipi = deger;
        });
      },
    );
  }

  // ------------------------------------------------------
  // TOPLAM
  // ------------------------------------------------------

  Widget _toplamAlani() {
    return AlisToplam(
      kalemSayisi: _sepet.length,
      toplamMiktar: _toplamMiktar,
      araToplam: _araToplam,
      iskonto: _toplamIskonto,
      kdv: _toplamKdv,
      genelToplam: _genelToplam,
    );
  }

  // ------------------------------------------------------
  // FOOTER
  // ------------------------------------------------------

  Widget _footerAlani() {
    return AlisFooter(
      kaydediliyor: _kaydediliyor,
      onKaydet: _alisiKaydet,
      onTemizle: _formuTemizle,
      onIptal: _iptalEt,
    );
  }

  Widget _irsaliyeTipiAltToplam() {
    return BelgeAltToplamCubugu(
      araToplam: _araToplam,
      iskontoToplam: _toplamIskonto,
      kdvToplam: _toplamKdv,
      genelToplam: _genelToplam,
      actions: [
        OutlinedButton.icon(
          onPressed: _kaydediliyor ? null : _formuTemizle,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Temizle'),
        ),
        OutlinedButton.icon(
          onPressed: _kaydediliyor ? null : _iptalEt,
          icon: const Icon(Icons.close),
          label: const Text('İptal'),
        ),
        ElevatedButton.icon(
          onPressed: _kaydediliyor ? null : _alisiKaydet,
          icon: _kaydediliyor
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(
            _kaydediliyor ? 'Kaydediliyor...' : 'Alışı Kaydet',
          ),
        ),
      ],
    );
  }


  // ------------------------------------------------------
  // MASAÜSTÜ DÜZEN
  // ------------------------------------------------------

  Widget _masaustuDuzeni() {
    return Column(
      children: [
        _kurumsalFaturaBasligi(),
        _header(),
        _irsaliyeAktarCubugu(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 470,
                child: IgnorePointer(
                  ignoring: _irsaliyeAktarModu,
                  child: Opacity(
                    opacity: _irsaliyeAktarModu ? 0.45 : 1,
                    child: AlisUrunArama(
                      onUrunSecildi: _sepeteEkle,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  margin: const EdgeInsets.all(8),
                  elevation: 0,
                  child: AlisGrid(
                    sepet: _sepet,
                    onMiktarDegisti: _miktarDegistir,
                    onFiyatDegistir: _fiyatDegistir,
                    onIskontoDegisti: _iskontoDegistir,
                    onKdvDegisti: _kdvDegistir,
                    onSil: _satirSil,
                  ),
                ),
              ),
            ],
          ),
        ),
        _irsaliyeTipiAltToplam(),
      ],
    );
  }

  // ------------------------------------------------------
  // DAR EKRAN DÜZENİ
  // ------------------------------------------------------

  Widget _darEkranDuzeni() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _kurumsalFaturaBasligi(),
          _header(),
          _irsaliyeAktarCubugu(),
          SizedBox(
            height: 300,
            child: IgnorePointer(
              ignoring: _irsaliyeAktarModu,
              child: Opacity(
                opacity:
                    _irsaliyeAktarModu
                        ? 0.45
                        : 1,
                child: AlisUrunArama(
                  onUrunSecildi:
                      _sepeteEkle,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 420,
            child: AlisGrid(
              sepet: _sepet,
              onMiktarDegisti: _miktarDegistir,
              onFiyatDegistir: _fiyatDegistir,
              onIskontoDegisti: _iskontoDegistir,
              onKdvDegisti: _kdvDegistir,
              onSil: _satirSil,
            ),
          ),
          _irsaliyeTipiAltToplam(),
        ],
      ),
    );
  }

  // ------------------------------------------------------
  // BUILD
  // ------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'SATIN ALMA FATURASI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Verileri yenile',
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
                  final masaustu =
                      constraints.maxWidth >= 1000;

                  if (masaustu) {
                    return _masaustuDuzeni();
                  }

                  return _darEkranDuzeni();
                },
              ),
            ),
    );
  }
}
