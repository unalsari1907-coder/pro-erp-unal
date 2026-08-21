// lib/screens/satis_faturalari_sayfasi.dart

import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../services/belge_pdf_service.dart';
import '../services/firma_ayarlari_service.dart';
import '../services/yetki_service.dart';
import '../services/calisma_sekmesi_service.dart';
import '../utils/marka_kod.dart';

import 'satis_sayfasi.dart';

class SatisFaturalariSayfasi extends StatefulWidget {
  const SatisFaturalariSayfasi({super.key});

  @override
  State<SatisFaturalariSayfasi> createState() => _SatisFaturalariSayfasiState();
}

class _SatisFaturalariSayfasiState extends State<SatisFaturalariSayfasi> {
  final TextEditingController _aramaController = TextEditingController();

  bool _yukleniyor = true;

  List<Map<String, dynamic>> _tumFaturalar = [];
  List<Map<String, dynamic>> _gorunenFaturalar = [];

  @override
  void initState() {
    super.initState();
    _aramaController.addListener(_filtrele);
    _faturalariYukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _yeniKayitAc() async {
    final sekmedeAcildi = CalismaSekmesiService.ac(
      'yeni_satis_faturasi',
      'Yeni Satış',
      const SatisSayfasi(),
    );
    if (sekmedeAcildi) return;

    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const SatisSayfasi()));

    if (!mounted) return;

    await _faturalariYukle();
  }

  Future<void> _faturalariYukle() async {
    if (!mounted) return;

    setState(() => _yukleniyor = true);

    try {
      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from('satis_baslik')
            .select(
              'satis_id, fatura_no, belge_no, tarih, cari_id, '
              'toplam_tutar, kdv_toplam, genel_toplam, durum, '
              'kullanici, depo_id, fiyat_tipi, odeme_tipi, kasa_id',
            )
            .order('tarih', ascending: false),
        SupabaseService.supabase.from('cariler').select('cari_id, unvan'),
        SupabaseService.supabase.from('depolar').select('depo_id, depo_adi'),
        SupabaseService.supabase.from('kasalar').select('kasa_id, kasa_adi'),
      ]);

      final faturalar = List<Map<String, dynamic>>.from(sonuclar[0] as List);
      final cariler = List<Map<String, dynamic>>.from(sonuclar[1] as List);
      final depolar = List<Map<String, dynamic>>.from(sonuclar[2] as List);
      final kasalar = List<Map<String, dynamic>>.from(sonuclar[3] as List);

      final cariAdlari = <int, String>{};
      for (final cari in cariler) {
        final id = int.tryParse(cari['cari_id'].toString());
        if (id != null) {
          cariAdlari[id] = cari['unvan']?.toString() ?? '';
        }
      }

      final depoAdlari = <int, String>{};
      for (final depo in depolar) {
        final id = int.tryParse(depo['depo_id'].toString());
        if (id != null) {
          depoAdlari[id] = depo['depo_adi']?.toString() ?? '';
        }
      }

      final kasaAdlari = <int, String>{};
      for (final kasa in kasalar) {
        final id = int.tryParse(kasa['kasa_id'].toString());
        if (id != null) {
          kasaAdlari[id] = kasa['kasa_adi']?.toString() ?? '';
        }
      }

      for (final fatura in faturalar) {
        final cariId = int.tryParse(fatura['cari_id'].toString());
        final depoId = int.tryParse(fatura['depo_id'].toString());
        final kasaId = int.tryParse(fatura['kasa_id'].toString());

        fatura['cari_unvan'] = cariId == null
            ? '-'
            : (cariAdlari[cariId] ?? '-');
        fatura['depo_adi'] = depoId == null ? '-' : (depoAdlari[depoId] ?? '-');
        fatura['kasa_adi'] = kasaId == null ? '-' : (kasaAdlari[kasaId] ?? '-');
      }

      if (!mounted) return;

      setState(() {
        _tumFaturalar = faturalar;
        _gorunenFaturalar = faturalar;
        _yukleniyor = false;
      });

      _filtrele();
    } catch (e) {
      if (!mounted) return;

      setState(() => _yukleniyor = false);
      _mesaj('Satış faturaları yüklenemedi: $e', Colors.red);
    }
  }

  void _filtrele() {
    final kelimeler = _aramaController.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (!mounted) return;

    setState(() {
      if (kelimeler.isEmpty) {
        _gorunenFaturalar = List<Map<String, dynamic>>.from(_tumFaturalar);
        return;
      }

      _gorunenFaturalar = _tumFaturalar.where((fatura) {
        final metin = [
          fatura['satis_id'],
          fatura['fatura_no'],
          fatura['belge_no'],
          fatura['cari_unvan'],
          fatura['odeme_tipi'],
          fatura['durum'],
          fatura['depo_adi'],
          fatura['kasa_adi'],
        ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();

        return kelimeler.every(metin.contains);
      }).toList();
    });
  }

  double _sayi(dynamic deger) {
    return double.tryParse(deger?.toString().replaceAll(',', '.') ?? '0') ??
        0.0;
  }

  String _para(dynamic deger) {
    return '${_sayi(deger).toStringAsFixed(2)} ₺';
  }

  String _metin(dynamic deger) {
    final sonuc = deger?.toString().trim() ?? '';
    return sonuc.isEmpty ? '-' : sonuc;
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

  Color _durumRengi(dynamic durum) {
    final metin = durum?.toString().toUpperCase() ?? '';

    if (metin.contains('IPTAL') || metin.contains('İPTAL')) {
      return Colors.red;
    }
    if (metin.contains('ONAY')) {
      return Colors.green;
    }
    return Colors.orange;
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
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

  Future<void> _whatsAppFaturaGonder(int satisId) async {
    try {
      final basliklar = List<Map<String, dynamic>>.from(
        await SupabaseService.supabase
            .from('satis_baslik')
            .select('satis_id, fatura_no, cari_id, genel_toplam')
            .eq('satis_id', satisId)
            .limit(1),
      );

      if (basliklar.isEmpty) {
        throw Exception('Satış faturası bulunamadı.');
      }

      final baslik = basliklar.first;
      final cariId = baslik['cari_id'];

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

      final unvan = _metin(cari['unvan']);
      final faturaNo = _metin(baslik['fatura_no']);
      final toplam = _para(baslik['genel_toplam']);

      // Normal WhatsApp doğrudan dosya eklemeye izin vermediği için
      // önce ürün kodu bulunmayan PDF oluşturulur, sonra hazır mesajla
      // müşterinin WhatsApp görüşmesi açılır.
      await BelgePdfService.satisPaylas(satisId);
      final firma = await FirmaAyarlariService.getir();

      final mesaj =
          'Sayın $unvan,\n\n'
          '$faturaNo numaralı satış faturanız hazırlanmıştır.\n'
          'Belge toplamı: $toplam\n\n'
          'Aldığınız parçalara ait faturayı ekte bilgilerinize sunarız.\n'
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

  Future<List<Map<String, dynamic>>> _kaynakSatisIrsaliyeleriGetir(
    int satisId,
  ) async {
    final baglantilar = await SupabaseService.supabase
        .from('satis_irsaliye_fatura')
        .select('irsaliye_id')
        .eq('satis_id', satisId);

    final ids = List<Map<String, dynamic>>.from(baglantilar)
        .map((e) => int.tryParse(e['irsaliye_id']?.toString() ?? ''))
        .whereType<int>()
        .toSet()
        .toList();

    if (ids.isEmpty) {
      return [];
    }

    final response = await SupabaseService.supabase
        .from('satis_irsaliye_baslik')
        .select(
          'irsaliye_id, irsaliye_no, tarih, '
          'sevk_tarihi, cari_id, depo_id, '
          'durum, aciklama, kullanici',
        )
        .inFilter('irsaliye_id', ids)
        .order('tarih');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _satisIrsaliyesiniAc(Map<String, dynamic> irsaliye) async {
    final irsaliyeId = int.tryParse(irsaliye['irsaliye_id']?.toString() ?? '');

    if (irsaliyeId == null) {
      _mesaj('Geçersiz irsaliye ID.', Colors.red);
      return;
    }

    try {
      // Önce sadece bu irsaliyenin detaylarını getir.
      final detayResponse = await SupabaseService.supabase
          .from('satis_irsaliye_detay')
          .select(
            'detay_id, stok_id, miktar, '
            'faturalanan_miktar, kalan_miktar, '
            'birim_fiyat, indirim_orani, '
            'kdv_orani, durum',
          )
          .eq('irsaliye_id', irsaliyeId)
          .order('detay_id');

      final detaylar = List<Map<String, dynamic>>.from(detayResponse);

      // Tüm stok tablosunu değil, yalnız bu irsaliyedeki
      // ürünlerin stok kartlarını getir.
      final stokIds = detaylar
          .map((d) => int.tryParse(d['stok_id']?.toString() ?? ''))
          .whereType<int>()
          .toSet()
          .toList();

      final stokResponse = stokIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await SupabaseService.supabase
                  .from('stoklar')
                  .select(
                    'stok_id, urun_adi, '
                    'uretici_kodu, oem_no, '
                    'marka, raf',
                  )
                  .inFilter('stok_id', stokIds),
            );

      final stokMap = <int, Map<String, dynamic>>{
        for (final stok in stokResponse)
          if (int.tryParse(stok['stok_id']?.toString() ?? '') != null)
            int.parse(stok['stok_id'].toString()): stok,
      };

      for (final detay in detaylar) {
        final stokId = int.tryParse(detay['stok_id']?.toString() ?? '');

        final stok = stokId == null ? null : stokMap[stokId];

        detay['urun_adi'] = stok?['urun_adi'] ?? '-';
        detay['uretici_kodu'] = stok?['uretici_kodu'] ?? '-';
        detay['marka'] = stok?['marka'] ?? '-';
        detay['raf'] = stok?['raf'] ?? '-';
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: MobilYatayRow(
              children: [
                const Icon(Icons.local_shipping_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Satış İrsaliyesi: '
                    '${_metin(irsaliye['irsaliye_no'])}',
                  ),
                ),
              ],
            ),
            content: MobilDialogIcerik(
              width: 980,
              height: 620,
              child: Column(
                children: [
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 28,
                        runSpacing: 10,
                        children: [
                          _detayBilgisi(
                            'İrsaliye No',
                            _metin(irsaliye['irsaliye_no']),
                          ),
                          _detayBilgisi('Tarih', _tarih(irsaliye['tarih'])),
                          _detayBilgisi('Durum', _metin(irsaliye['durum'])),
                          _detayBilgisi(
                            'Kullanıcı',
                            _metin(irsaliye['kullanici']),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: detaylar.isEmpty
                        ? const Center(
                            child: Text('İrsaliye kalemi bulunamadı.'),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: MobilTablo(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Ürün')),
                                    DataColumn(label: Text('Marka / Kod')),
                                    DataColumn(label: Text('RAF')),
                                    DataColumn(label: Text('Miktar')),
                                    DataColumn(label: Text('Birim Fiyat')),
                                    DataColumn(label: Text('KDV %')),
                                  ],
                                  rows: detaylar.map((detay) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 300,
                                            child: Text(
                                              _metin(detay['urun_adi']),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            markaVeUreticiKodu(
                                              detay['marka'],
                                              detay['uretici_kodu'],
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(_metin(detay['raf']))),
                                        DataCell(Text(_metin(detay['miktar']))),
                                        DataCell(
                                          Text(_para(detay['birim_fiyat'])),
                                        ),
                                        DataCell(
                                          Text(_metin(detay['kdv_orani'])),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Kapat'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      _mesaj('İrsaliye açılamadı: $e', Colors.red);
    }
  }

  Future<void> _satisIrsaliyeleriniCagir(
    List<Map<String, dynamic>> irsaliyeler,
  ) async {
    if (irsaliyeler.isEmpty) {
      _mesaj('Bu faturaya bağlı satış irsaliyesi yok.', Colors.orange);
      return;
    }

    if (irsaliyeler.length == 1) {
      await _satisIrsaliyesiniAc(irsaliyeler.first);
      return;
    }

    final secilen = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kaynak Satış İrsaliyeleri'),
          content: MobilDialogIcerik(
            width: 620,
            height: 420,
            child: ListView.separated(
              itemCount: irsaliyeler.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final irsaliye = irsaliyeler[index];

                return ListTile(
                  leading: const Icon(Icons.local_shipping_rounded),
                  title: Text(
                    _metin(irsaliye['irsaliye_no']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${_tarih(irsaliye['tarih'])} • '
                    '${_metin(irsaliye['durum'])}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(dialogContext, irsaliye);
                  },
                );
              },
            ),
          ),
          actions: [
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

    if (secilen != null && mounted) {
      await _satisIrsaliyesiniAc(secilen);
    }
  }

  Future<void> _faturaDetayiniGoster(Map<String, dynamic> fatura) async {
    final satisId = int.tryParse(fatura['satis_id'].toString());

    if (satisId == null) {
      _mesaj('Geçersiz satış ID.', Colors.red);
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final kaynakIrsaliyeler = await _kaynakSatisIrsaliyeleriGetir(satisId);

      final sonuclar = await Future.wait([
        SupabaseService.supabase
            .from('satis_detay')
            .select(
              'stok_id, miktar, birim_fiyat, indirim, kdv_orani, '
              'tutar, toplam_tutar',
            )
            .eq('satis_id', satisId)
            .order('stok_id'),
        SupabaseService.supabase
            .from('stoklar')
            .select('stok_id, urun_adi, uretici_kodu, oem_no, marka, raf'),
      ]);

      final detaylar = List<Map<String, dynamic>>.from(sonuclar[0] as List);
      final stoklar = List<Map<String, dynamic>>.from(sonuclar[1] as List);

      final stokHaritasi = <int, Map<String, dynamic>>{};
      for (final stok in stoklar) {
        final stokId = int.tryParse(stok['stok_id'].toString());
        if (stokId != null) {
          stokHaritasi[stokId] = stok;
        }
      }

      for (final detay in detaylar) {
        final stokId = int.tryParse(detay['stok_id'].toString());
        final stok = stokId == null ? null : stokHaritasi[stokId];

        detay['urun_adi'] = stok?['urun_adi'] ?? '-';
        detay['uretici_kodu'] = stok?['uretici_kodu'] ?? '-';
        detay['marka'] = stok?['marka'] ?? '-';
        detay['oem_no'] = stok?['oem_no'] ?? '-';
        detay['raf'] = stok?['raf'] ?? '-';
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      await showDialog<void>(
        context: context,
        builder: (detayContext) {
          return AlertDialog(
            title: MobilYatayRow(
              children: [
                const Icon(Icons.receipt_long_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Satış Faturası: ${_metin(fatura['fatura_no'])}'),
                ),
              ],
            ),
            content: MobilDialogIcerik(
              width: 1050,
              height: 680,
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 28,
                        runSpacing: 10,
                        children: [
                          _detayBilgisi(
                            'Fatura No',
                            _metin(fatura['fatura_no']),
                          ),
                          _detayBilgisi(
                            'Müşteri',
                            _metin(fatura['cari_unvan']),
                          ),
                          _detayBilgisi('Tarih', _tarih(fatura['tarih'])),
                          _detayBilgisi(
                            'Ödeme Tipi',
                            _metin(fatura['odeme_tipi']),
                          ),
                          _detayBilgisi('Depo', _metin(fatura['depo_adi'])),
                          _detayBilgisi('Kasa', _metin(fatura['kasa_adi'])),
                          if (kaynakIrsaliyeler.isNotEmpty)
                            _detayBilgisi(
                              'Kaynak İrsaliye',
                              kaynakIrsaliyeler
                                  .map((e) => _metin(e['irsaliye_no']))
                                  .join(', '),
                            ),
                          _detayBilgisi('Belge Tipi', 'FATURA'),
                          _detayBilgisi('Durum', _metin(fatura['durum'])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: detaylar.isEmpty
                        ? const Center(
                            child: Text('Bu faturaya ait kalem bulunamadı.'),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: MobilTablo(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Ürün')),
                                    DataColumn(label: Text('Marka / Kod')),
                                    DataColumn(label: Text('RAF')),
                                    DataColumn(label: Text('Miktar')),
                                    DataColumn(label: Text('Birim Fiyat')),
                                    DataColumn(label: Text('KDV %')),
                                    DataColumn(label: Text('Toplam')),
                                  ],
                                  rows: detaylar.map((detay) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 300,
                                            child: Text(
                                              _metin(detay['urun_adi']),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            markaVeUreticiKodu(
                                              detay['marka'],
                                              detay['uretici_kodu'],
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(_metin(detay['raf']))),
                                        DataCell(Text(_metin(detay['miktar']))),
                                        DataCell(
                                          Text(_para(detay['birim_fiyat'])),
                                        ),
                                        DataCell(
                                          Text(_metin(detay['kdv_orani'])),
                                        ),
                                        DataCell(
                                          Text(
                                            _para(
                                              detay['toplam_tutar'] ??
                                                  detay['tutar'],
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const Divider(),
                  MobilYatayRow(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _toplamKutusu(
                        'Ara Toplam',
                        _para(fatura['toplam_tutar']),
                      ),
                      const SizedBox(width: 12),
                      _toplamKutusu('KDV', _para(fatura['kdv_toplam'])),
                      const SizedBox(width: 12),
                      _toplamKutusu(
                        'Genel Toplam',
                        _para(fatura['genel_toplam']),
                        vurgulu: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              if (kaynakIrsaliyeler.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    await _satisIrsaliyeleriniCagir(kaynakIrsaliyeler);
                  },
                  icon: const Icon(Icons.local_shipping_rounded),
                  label: Text(
                    kaynakIrsaliyeler.length == 1
                        ? 'İrsaliyeyi Aç'
                        : 'İrsaliyeler '
                              '(${kaynakIrsaliyeler.length})',
                  ),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: _durumRengi(fatura['durum']) == Colors.red
                    ? null
                    : () {
                        _faturaIptalEt(fatura, acikDetayContext: detayContext);
                      },
                icon: const Icon(Icons.cancel),
                label: const Text('Faturayı İptal Et'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final izin = await YetkiService.kontrolEt(context, 'pdf');

                  if (!izin) return;

                  try {
                    await BelgePdfService.satisPaylas(satisId);
                  } catch (e) {
                    if (!mounted) return;

                    _mesaj('PDF oluşturma hatası: $e', Colors.red);
                  }
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Müşteri PDF / Paylaş'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                ),
                onPressed: () async {
                  final izin = await YetkiService.kontrolEt(context, 'pdf');

                  if (!izin) return;

                  await _whatsAppFaturaGonder(satisId);
                },
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp Gönder'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final izin = await YetkiService.kontrolEt(context, 'pdf');

                  if (!izin) return;

                  try {
                    await BelgePdfService.satisDepoYazdir(satisId);
                  } catch (e) {
                    if (!mounted) return;

                    _mesaj('Yazdırma hatası: $e', Colors.red);
                  }
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Depo Çıktısı'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final izin = await YetkiService.kontrolEt(context, 'pdf');

                  if (!izin) return;

                  try {
                    await BelgePdfService.satisMusteriYazdir(satisId);
                  } catch (e) {
                    if (!mounted) return;

                    _mesaj('Müşteri çıktısı hatası: $e', Colors.red);
                  }
                },
                icon: const Icon(Icons.print_outlined),
                label: const Text('Müşteri Çıktısı'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(detayContext);
                },
                child: const Text('Kapat'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      _mesaj('Fatura detayları yüklenemedi: $e', Colors.red);
    }
  }

  Future<void> _faturaIptalEt(
    Map<String, dynamic> fatura, {
    BuildContext? acikDetayContext,
  }) async {
    final satisId = int.tryParse(fatura['satis_id']?.toString() ?? '');

    if (satisId == null) {
      _mesaj('Geçersiz satış ID.', Colors.red);
      return;
    }

    final durum = fatura['durum']?.toString().toUpperCase() ?? '';

    if (durum.contains('IPTAL') || durum.contains('İPTAL')) {
      _mesaj('Bu satış faturası zaten iptal edilmiş.', Colors.orange);
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Satış Faturasını İptal Et'),
          content: Text(
            'Fatura No: ${_metin(fatura['fatura_no'])}\n'
            'Cari: ${_metin(fatura['cari_unvan'])}\n'
            'Genel Toplam: ${_para(fatura['genel_toplam'])}\n\n'
            'Bu işlem:\n'
            '• Satılan ürünleri stoğa geri ekler.\n'
            '• Cari hareketini ters kayıtla kapatır.\n'
            '• Peşin satışta kasa çıkışı oluşturur.\n'
            '• Fatura durumunu İPTAL yapar.\n\n'
            'İşlem geri alınamaz. Devam edilsin mi?',
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
              icon: const Icon(Icons.cancel),
              label: const Text('Evet, İptal Et'),
            ),
          ],
        );
      },
    );

    if (onay != true) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      await SupabaseService.supabase.rpc(
        'satis_faturasi_iptal_et',
        params: {
          'p_satis_id': satisId,
          'p_kullanici': YetkiService.aktifKullanici,
        },
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      if (acikDetayContext != null && acikDetayContext.mounted) {
        Navigator.pop(acikDetayContext);
      }

      _mesaj('Satış faturası başarıyla iptal edildi.', Colors.green);

      await _faturalariYukle();
    } catch (e) {
      if (!mounted) return;

      final navigator = Navigator.of(context);

      if (navigator.canPop()) {
        navigator.pop();
      }

      _mesaj('Fatura iptal hatası: $e', Colors.red);
    }
  }

  Widget _detayBilgisi(String baslik, String deger) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(deger, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _toplamKutusu(String baslik, String deger, {bool vurgulu = false}) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: vurgulu ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            baslik,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            deger,
            style: TextStyle(
              fontSize: vurgulu ? 18 : 15,
              fontWeight: FontWeight.bold,
              color: vurgulu ? Colors.blue.shade800 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _faturaKarti(Map<String, dynamic> fatura) {
    final durumRengi = _durumRengi(fatura['durum']);

    if (MobilUyum.telefon(context)) {
      return _mobilFaturaKarti(fatura, durumRengi);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _faturaDetayiniGoster(fatura);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: MobilYatayRow(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.receipt_long, color: Colors.blue),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metin(fatura['fatura_no']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tarih(fatura['tarih']),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _metin(fatura['cari_unvan']),
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
                        Text('Belge: ${_metin(fatura['belge_no'])}'),
                        Text('Ödeme: ${_metin(fatura['odeme_tipi'])}'),
                        Text('Depo: ${_metin(fatura['depo_adi'])}'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _para(fatura['genel_toplam']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _metin(fatura['durum']),
                      style: TextStyle(
                        color: durumRengi,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'İşlemler',
                onSelected: (deger) {
                  if (deger == 'goruntule') {
                    _faturaDetayiniGoster(fatura);
                  } else if (deger == 'pdf') {
                    YetkiService.kontrolEt(context, 'pdf').then((ok) {
                      if (ok)
                        BelgePdfService.satisPaylas(
                          int.parse(fatura['satis_id'].toString()),
                        );
                    });
                  } else if (deger == 'depo_yazdir') {
                    YetkiService.kontrolEt(context, 'pdf').then((ok) {
                      if (ok)
                        BelgePdfService.satisDepoYazdir(
                          int.parse(fatura['satis_id'].toString()),
                        );
                    });
                  } else if (deger == 'musteri_yazdir') {
                    YetkiService.kontrolEt(context, 'pdf').then((ok) {
                      if (ok)
                        BelgePdfService.satisMusteriYazdir(
                          int.parse(fatura['satis_id'].toString()),
                        );
                    });
                  } else if (deger == 'iptal') {
                    _faturaIptalEt(fatura);
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem<String>(
                      value: 'goruntule',
                      child: ListTile(
                        leading: Icon(Icons.visibility),
                        title: Text('Görüntüle'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_outlined),
                        title: Text('Müşteri PDF / Paylaş'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'depo_yazdir',
                      child: ListTile(
                        leading: Icon(Icons.inventory_2_outlined),
                        title: Text('Depo Çıktısı'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'musteri_yazdir',
                      child: ListTile(
                        leading: Icon(Icons.print_outlined),
                        title: Text('Müşteri Çıktısı'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'iptal',
                      child: ListTile(
                        leading: Icon(Icons.cancel, color: Colors.red),
                        title: Text(
                          'Faturayı İptal Et',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobilFaturaKarti(Map<String, dynamic> fatura, Color durumRengi) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _faturaDetayiniGoster(fatura),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.receipt_long, color: Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _metin(fatura['fatura_no']),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _tarih(fatura['tarih']),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _mobilFaturaMenusu(fatura),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _metin(fatura['cari_unvan']),
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
                  Text('Belge: ${_metin(fatura['belge_no'])}'),
                  Text('Ödeme: ${_metin(fatura['odeme_tipi'])}'),
                  Text('Depo: ${_metin(fatura['depo_adi'])}'),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Text(
                    _metin(fatura['durum']),
                    style: TextStyle(
                      color: durumRengi,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _para(fatura['genel_toplam']),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobilFaturaMenusu(Map<String, dynamic> fatura) {
    return PopupMenuButton<String>(
      tooltip: 'İşlemler',
      onSelected: (deger) {
        if (deger == 'goruntule') {
          _faturaDetayiniGoster(fatura);
        } else if (deger == 'pdf') {
          YetkiService.kontrolEt(context, 'pdf').then((ok) {
            if (ok) {
              BelgePdfService.satisPaylas(
                int.parse(fatura['satis_id'].toString()),
              );
            }
          });
        } else if (deger == 'depo_yazdir') {
          YetkiService.kontrolEt(context, 'pdf').then((ok) {
            if (ok) {
              BelgePdfService.satisDepoYazdir(
                int.parse(fatura['satis_id'].toString()),
              );
            }
          });
        } else if (deger == 'musteri_yazdir') {
          YetkiService.kontrolEt(context, 'pdf').then((ok) {
            if (ok) {
              BelgePdfService.satisMusteriYazdir(
                int.parse(fatura['satis_id'].toString()),
              );
            }
          });
        } else if (deger == 'iptal') {
          _faturaIptalEt(fatura);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'goruntule', child: Text('Görüntüle')),
        PopupMenuItem(value: 'pdf', child: Text('PDF / Paylaş')),
        PopupMenuItem(value: 'depo_yazdir', child: Text('Depo Çıktısı')),
        PopupMenuItem(value: 'musteri_yazdir', child: Text('Müşteri Çıktısı')),
        PopupMenuItem(
          value: 'iptal',
          child: Text('Faturayı İptal Et', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MobilUyum.telefon(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'SATIŞ FATURALARI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          MobilAppBarActions(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: _yukleniyor ? null : _yeniKayitAc,
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Satış'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Yenile',
                onPressed: _yukleniyor ? null : _faturalariYukle,
                icon: const Icon(Icons.refresh),
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
            child: TextField(
              controller: _aramaController,
              decoration: InputDecoration(
                hintText: 'Fatura no, belge no, cari, ödeme tipi, durum...',
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
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _gorunenFaturalar.isEmpty
                ? const Center(
                    child: Text(
                      'Satış faturası bulunamadı.',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _faturalariYukle,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _gorunenFaturalar.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _faturaKarti(_gorunenFaturalar[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: mobil
          ? FloatingActionButton.extended(
              onPressed: _yukleniyor ? null : _yeniKayitAc,
              icon: const Icon(Icons.add),
              label: const Text('Yeni Satış'),
            )
          : null,
    );
  }
}
