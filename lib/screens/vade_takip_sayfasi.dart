import 'package:flutter/material.dart';
import '../services/sayfali_veri_service.dart';
import '../services/supabase_service.dart';
import '../services/yetki_service.dart';

class VadeTakipSayfasi extends StatefulWidget {
  const VadeTakipSayfasi({super.key});

  @override
  State<VadeTakipSayfasi> createState() =>
      _VadeTakipSayfasiState();
}

class _VadeTakipSayfasiState
    extends State<VadeTakipSayfasi> {
  final TextEditingController _arama =
      TextEditingController();

  bool _yukleniyor = true;
  bool _sadeceGeciken = true;

  List<Map<String, dynamic>> _tum = [];
  List<Map<String, dynamic>> _liste = [];
  List<Map<String, dynamic>> _kasalar = [];

  @override
  void initState() {
    super.initState();
    _arama.addListener(_filtrele);
    _yukle();
  }

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  double _sayi(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().replaceAll(',', '.') ?? '0',
        ) ??
        0;
  }

  String _para(dynamic value) {
    return '${_sayi(value).toStringAsFixed(2)} TL';
  }

  String _tarih(dynamic value) {
    final tarih = DateTime.tryParse(
      value?.toString() ?? '',
    )?.toLocal();

    if (tarih == null) {
      return '-';
    }

    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year}';
  }

  Future<void> _yukle() async {
    if (mounted) {
      setState(() {
        _yukleniyor = true;
      });
    }

    try {
      final sonuclar = await Future.wait([
        SayfaliVeriService.tumunuGetir(
          (baslangic, bitis) => SupabaseService.supabase
              .from('erp_vade_takip')
              .select()
              .order('vade_tarihi')
              .range(baslangic, bitis),
        ),
        SupabaseService.supabase
            .from('kasalar')
            .select('kasa_id, kasa_adi, kasa_tipi')
            .order('kasa_adi'),
      ]);

      if (!mounted) return;

      setState(() {
        _tum =
            List<Map<String, dynamic>>.from(
          sonuclar[0] as List,
        );
        _kasalar =
            List<Map<String, dynamic>>.from(
          sonuclar[1] as List,
        );
        _yukleniyor = false;
      });

      _filtrele();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _yukleniyor = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vade listesi yüklenemedi: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filtrele() {
    final kelimeler = _arama.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (!mounted) return;

    setState(() {
      _liste = _tum.where((kayit) {
        final gecikmeGun =
            (kayit['gecikme_gun'] as num?)
                    ?.toInt() ??
                0;

        if (_sadeceGeciken &&
            gecikmeGun <= 0) {
          return false;
        }

        if (kelimeler.isEmpty) {
          return true;
        }

        final metin = [
          kayit['cari_unvan'],
          kayit['fatura_no'],
          kayit['belge_tipi'],
          kayit['yon'],
          kayit['durum'],
        ]
            .map(
              (e) => e?.toString() ?? '',
            )
            .join(' ')
            .toLowerCase();

        return kelimeler.every(
          metin.contains,
        );
      }).toList();
    });
  }

  Future<void> _odemeKaydet(
    Map<String, dynamic> kayit,
  ) async {
    if (_kasalar.isEmpty) {
      _mesaj(
        'Ödeme kaydı için aktif bir kasa/banka bulunamadı.',
        Colors.red,
      );
      return;
    }

    final kalanTutar = _sayi(kayit['kalan_tutar']);
    final controller = TextEditingController(
      text: kalanTutar.toStringAsFixed(2),
    );
    final aciklamaController = TextEditingController(
      text: '${kayit['fatura_no'] ?? '-'} vade kapama işlemi',
    );

    int? secilenKasaId = int.tryParse(
      _kasalar.first['kasa_id']?.toString() ?? '',
    );

    final sonuc =
        await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                kayit['belge_tipi'] == 'SATIS'
                    ? 'Tahsilat Kaydet'
                    : 'Ödeme Kaydet',
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${kayit['cari_unvan'] ?? '-'} • '
                        '${kayit['fatura_no'] ?? '-'}\n'
                        'Kalan: ${_para(kalanTutar)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: secilenKasaId,
                      decoration: const InputDecoration(
                        labelText: 'Kasa / Banka / POS',
                        border: OutlineInputBorder(),
                      ),
                      items: _kasalar.map((kasa) {
                        final id = int.tryParse(
                          kasa['kasa_id']?.toString() ?? '',
                        );
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            kasa['kasa_adi']?.toString() ?? '-',
                          ),
                        );
                      }).where((item) => item.value != null).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          secilenKasaId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'İşlem Tutarı',
                        suffixText: 'TL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: aciklamaController,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        border: OutlineInputBorder(),
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
                    final tutar = double.tryParse(
                          controller.text.replaceAll(',', '.'),
                        ) ??
                        0;

                    if (secilenKasaId == null ||
                        tutar <= 0 ||
                        tutar > kalanTutar + 0.001) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Kasa seçin ve kalan tutarı aşmayan geçerli bir tutar girin.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      <String, dynamic>{
                        'kasa_id': secilenKasaId,
                        'tutar': tutar,
                        'aciklama': aciklamaController.text.trim(),
                      },
                    );
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

    controller.dispose();
    aciklamaController.dispose();

    if (sonuc == null) return;

    try {
      var cariId = int.tryParse(kayit['cari_id']?.toString() ?? '');
      if (cariId == null) {
        final satisMi = kayit['belge_tipi']?.toString().toUpperCase() == 'SATIS';
        final tablo = satisMi ? 'satis_baslik' : 'alis_baslik';
        final idAlan = satisMi ? 'satis_id' : 'alis_id';
        final baslik = await SupabaseService.supabase
            .from(tablo)
            .select('cari_id')
            .eq(idAlan, kayit['belge_id'])
            .maybeSingle();
        cariId = int.tryParse(baslik?['cari_id']?.toString() ?? '');
      }
      if (cariId == null) {
        throw Exception('Faturanın cari hesabı bulunamadı.');
      }

      await SupabaseService.supabase.rpc(
        'erp_vade_odeme_kaydet',
        params: {
          'p_belge_tipi': kayit['belge_tipi'],
          'p_belge_id': kayit['belge_id'],
          'p_cari_id': cariId,
          'p_kasa_id': sonuc['kasa_id'],
          'p_tutar': sonuc['tutar'],
          'p_tarih': DateTime.now().toUtc().toIso8601String(),
          'p_kullanici': YetkiService.aktifKullanici,
          'p_aciklama': sonuc['aciklama'],
        },
      );

      if (!mounted) return;
      _mesaj(
        kayit['belge_tipi'] == 'SATIS'
            ? 'Tahsilat; fatura, cari ve kasaya birlikte kaydedildi.'
            : 'Ödeme; fatura, cari ve kasaya birlikte kaydedildi.',
        Colors.green,
      );
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj('Vade işlemi kaydedilemedi: $e', Colors.red);
    }
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: renk),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toplamKalan =
        _liste.fold<double>(
      0,
      (toplam, kayit) =>
          toplam +
          _sayi(
            kayit['kalan_tutar'],
          ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VADE / ALACAK - BORÇ TAKİBİ',
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _yukle,
            icon:
                const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _arama,
                    decoration:
                        const InputDecoration(
                      hintText:
                          'Cari, fatura no, belge tipi...',
                      prefixIcon:
                          Icon(Icons.search),
                      border:
                          OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  selected:
                      _sadeceGeciken,
                  label: const Text(
                    'Sadece Geciken',
                  ),
                  onSelected: (value) {
                    _sadeceGeciken =
                        value;
                    _filtrele();
                  },
                ),
                const SizedBox(width: 12),
                Chip(
                  avatar: const Icon(
                    Icons.warning_amber,
                    size: 18,
                  ),
                  label: Text(
                    'Kalan: '
                    '${_para(toplamKalan)}',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : _liste.isEmpty
                    ? const Center(
                        child: Text(
                          'Vade kaydı yok.',
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets
                                .all(12),
                        itemCount:
                            _liste.length,
                        separatorBuilder:
                            (_, __) =>
                                const SizedBox(
                          height: 7,
                        ),
                        itemBuilder:
                            (_, index) {
                          final kayit =
                              _liste[index];

                          final gecikmeGun =
                              (kayit[
                                          'gecikme_gun']
                                      as num?)
                                  ?.toInt() ??
                              0;

                          final satis =
                              kayit[
                                      'belge_tipi'] ==
                                  'SATIS';

                          return Card(
                            child: ListTile(
                              leading:
                                  CircleAvatar(
                                child: Icon(
                                  satis
                                      ? Icons
                                          .trending_up
                                      : Icons
                                          .trending_down,
                                ),
                              ),
                              title: Text(
                                kayit[
                                            'cari_unvan']
                                        ?.toString() ??
                                    '-',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                              subtitle: Text(
                                '${satis ? 'SATIŞ / ALACAK' : 'ALIŞ / BORÇ'}'
                                ' • ${kayit['fatura_no'] ?? '-'}'
                                ' • Vade: ${_tarih(kayit['vade_tarihi'])}'
                                '${gecikmeGun > 0 ? ' • $gecikmeGun gün gecikmiş' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize:
                                    MainAxisSize
                                        .min,
                                children: [
                                  Text(
                                    _para(
                                      kayit[
                                          'kalan_tutar'],
                                    ),
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      color:
                                          gecikmeGun >
                                                  0
                                              ? Colors
                                                  .red
                                              : Colors
                                                  .green,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        satis
                                            ? 'Tahsilat kaydet'
                                            : 'Ödeme kaydet',
                                    onPressed: () {
                                      _odemeKaydet(
                                        kayit,
                                      );
                                    },
                                    icon:
                                        const Icon(
                                      Icons
                                          .edit_note,
                                    ),
                                  ),
                                ],
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
