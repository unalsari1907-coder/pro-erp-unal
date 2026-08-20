// lib/screens/cariler_sayfasi.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import '../services/cari_ekstre_service.dart';
import '../services/sayfali_veri_service.dart';
import '../services/supabase_service.dart';
import 'widgets/stok_belge_detay_dialog.dart';

class CarilerSayfasi extends StatefulWidget {
  const CarilerSayfasi({super.key});

  @override
  State<CarilerSayfasi> createState() => _CarilerSayfasiState();
}

class _CarilerSayfasiState extends State<CarilerSayfasi> {
  final TextEditingController _aramaController = TextEditingController();
  Timer? _aramaTimer;

  bool _yukleniyor = true;
  bool _kaydediliyor = false;
  String _tipFiltresi = 'TÜMÜ';

  List<Map<String, dynamic>> _tumCariler = [];
  List<Map<String, dynamic>> _gorunenCariler = [];

  @override
  void initState() {
    super.initState();
    _aramaController.addListener(_aramaDegisti);
    _carileriYukle();
  }

  @override
  void dispose() {
    _aramaTimer?.cancel();
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _carileriYukle() async {
    if (!mounted) return;
    setState(() => _yukleniyor = true);

    try {
      final response = await SayfaliVeriService.tumunuGetir(
        (baslangic, bitis) => SupabaseService.supabase
            .from('cariler')
            .select(
              'cari_id, cari_tipi, unvan, yetkili, telefon, eposta, '
              'vergi_no, vergi_dairesi, adres, il, ilce, risk_limiti, '
              'aktif, fiyat_tipi, bakiye, son_alis_tarihi, '
              'son_satis_tarihi, notlar, created_at',
            )
            .order('unvan')
            .range(baslangic, bitis),
      );

      if (!mounted) return;
      setState(() {
        _tumCariler = List<Map<String, dynamic>>.from(response);
        _yukleniyor = false;
      });
      _filtrele();
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _mesaj('Cariler yüklenemedi: $e', Colors.red);
    }
  }

  void _aramaDegisti() {
    _aramaTimer?.cancel();
    _aramaTimer = Timer(const Duration(milliseconds: 250), _filtrele);
    if (mounted) setState(() {});
  }

  void _filtrele() {
    final kelimeler = _aramaController.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    final sonuc = _tumCariler.where((cari) {
      if (cari['aktif'] == false) return false;

      final tip = _metin(cari['cari_tipi']).toUpperCase();
      final tipUyuyor =
          _tipFiltresi == 'TÜMÜ' ||
          (_tipFiltresi == 'TEDARİKÇİ' &&
              (tip.contains('TEDARIK') || tip.contains('TEDARİK'))) ||
          (_tipFiltresi == 'MÜŞTERİ' &&
              (tip.contains('MUSTERI') || tip.contains('MÜŞTERİ'))) ||
          (_tipFiltresi == 'KARMA' && tip.contains('/'));

      if (!tipUyuyor) return false;
      if (kelimeler.isEmpty) return true;

      final metin = [
        cari['unvan'],
        cari['cari_tipi'],
        cari['yetkili'],
        cari['telefon'],
        cari['eposta'],
        cari['vergi_no'],
        cari['vergi_dairesi'],
        cari['adres'],
        cari['il'],
        cari['ilce'],
        cari['fiyat_tipi'],
        cari['notlar'],
      ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();

      return kelimeler.every(metin.contains);
    }).toList();

    if (!mounted) return;
    setState(() => _gorunenCariler = sonuc);
  }

  String _metin(dynamic deger) => deger?.toString().trim() ?? '';

  double _sayi(dynamic deger) {
    return double.tryParse(deger?.toString().replaceAll(',', '.') ?? '0') ?? 0;
  }

  String _para(dynamic deger) => '${_sayi(deger).toStringAsFixed(2)} ₺';

  String _tarih(dynamic deger) {
    final metin = _metin(deger);
    if (metin.isEmpty) return '-';
    final tarih = DateTime.tryParse(metin)?.toLocal();
    if (tarih == null) return metin;
    return '${tarih.day.toString().padLeft(2, '0')}.'
        '${tarih.month.toString().padLeft(2, '0')}.'
        '${tarih.year} '
        '${tarih.hour.toString().padLeft(2, '0')}:'
        '${tarih.minute.toString().padLeft(2, '0')}';
  }

  double _gosterimBorc(Map<String, dynamic> hareket) {
    final tip = _metin(hareket['islem_tipi']).toUpperCase();
    if (tip == 'VIRMAN_TEDARIKCI' || tip == 'VİRMAN_TEDARİKÇİ') {
      return _sayi(hareket['borc']) + _sayi(hareket['alacak']);
    }
    return _sayi(hareket['borc']);
  }

  double _gosterimAlacak(Map<String, dynamic> hareket) {
    final tip = _metin(hareket['islem_tipi']).toUpperCase();
    if (tip == 'VIRMAN_TEDARIKCI' || tip == 'VİRMAN_TEDARİKÇİ') return 0;
    return _sayi(hareket['alacak']);
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  Color _bakiyeRengi(Map<String, dynamic> cari) {
    final durum = _bakiyeDurumu(cari);
    if (durum.contains('ALACAK')) return Colors.green.shade700;
    if (durum.contains('BORÇ')) return Colors.red.shade700;
    return Colors.grey.shade700;
  }

  String _bakiyeDurumu(Map<String, dynamic> cari) {
    final bakiye = _sayi(cari['bakiye']);
    final tip = _metin(cari['cari_tipi']).toUpperCase();

    if (bakiye == 0) return 'HESAP KAPALI';
    if (tip.contains('TEDARIK') || tip.contains('TEDARİK')) {
      return bakiye > 0
          ? 'TEDARİKÇİYE BORÇLUYUZ'
          : 'TEDARİKÇİDEN ALACAKLIYIZ';
    }
    return bakiye > 0
        ? 'MÜŞTERİDEN ALACAKLIYIZ'
        : 'MÜŞTERİYE BORÇLUYUZ';
  }

  int get _aktifCariSayisi =>
      _tumCariler.where((e) => e['aktif'] != false).length;

  double get _toplamCariAlacagimiz =>
      _tumCariler.fold<double>(0, (toplam, cari) {
        final bakiye = _sayi(cari['bakiye']);
        return _bakiyeDurumu(cari).contains('ALACAK')
            ? toplam + bakiye.abs()
            : toplam;
      });

  double get _toplamCariBorcumuz => _tumCariler.fold<double>(0, (toplam, cari) {
    final bakiye = _sayi(cari['bakiye']);
    return _bakiyeDurumu(cari).contains('BORÇ')
        ? toplam + bakiye.abs()
        : toplam;
  });

  Future<void> _cariFormu({Map<String, dynamic>? cari}) async {
    final unvanController = TextEditingController(text: _metin(cari?['unvan']));
    final yetkiliController = TextEditingController(
      text: _metin(cari?['yetkili']),
    );
    final telefonController = TextEditingController(
      text: _metin(cari?['telefon']),
    );
    final epostaController = TextEditingController(
      text: _metin(cari?['eposta']),
    );
    final vergiNoController = TextEditingController(
      text: _metin(cari?['vergi_no']),
    );
    final vergiDairesiController = TextEditingController(
      text: _metin(cari?['vergi_dairesi']),
    );
    final adresController = TextEditingController(text: _metin(cari?['adres']));
    final ilController = TextEditingController(text: _metin(cari?['il']));
    final ilceController = TextEditingController(text: _metin(cari?['ilce']));
    final riskController = TextEditingController(
      text: _sayi(cari?['risk_limiti']).toStringAsFixed(2),
    );
    final notlarController = TextEditingController(
      text: _metin(cari?['notlar']),
    );

    String cariTipi = _metin(cari?['cari_tipi']).isEmpty
        ? 'MUSTERI'
        : _metin(cari?['cari_tipi']);
    String fiyatTipi = _metin(cari?['fiyat_tipi']).isEmpty
        ? 'PERAKENDE'
        : _metin(cari?['fiyat_tipi']);
    bool aktif = cari?['aktif'] != false;

    final sonuc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(cari == null ? 'Yeni Cari Kartı' : 'Cari Düzenle'),
              content: MobilDialogIcerik(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      MobilYatayRow(
                        mobilDikey: true,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: cariTipi,
                              decoration: const InputDecoration(
                                labelText: 'Cari Tipi',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'MUSTERI',
                                  child: Text('Müşteri'),
                                ),
                                DropdownMenuItem(
                                  value: 'TEDARIKCI',
                                  child: Text('Tedarikçi'),
                                ),
                                DropdownMenuItem(
                                  value: 'TEDARIKCI/MUSTERI',
                                  child: Text('Tedarikçi / Müşteri'),
                                ),
                              ],
                              onChanged: (deger) {
                                if (deger == null) return;
                                setDialogState(() => cariTipi = deger);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: fiyatTipi,
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
                              onChanged: (deger) {
                                if (deger == null) return;
                                setDialogState(() => fiyatTipi = deger);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _formAlani(unvanController, 'Ünvan'),
                      const SizedBox(height: 10),
                      MobilYatayRow(
                        mobilDikey: true,
                        children: [
                          Expanded(
                            child: _formAlani(yetkiliController, 'Yetkili'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _formAlani(telefonController, 'Telefon'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _formAlani(epostaController, 'E-posta'),
                      const SizedBox(height: 10),
                      MobilYatayRow(
                        mobilDikey: true,
                        children: [
                          Expanded(
                            child: _formAlani(vergiNoController, 'Vergi No'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _formAlani(
                              vergiDairesiController,
                              'Vergi Dairesi',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _formAlani(adresController, 'Adres', maxLines: 3),
                      const SizedBox(height: 10),
                      MobilYatayRow(
                        mobilDikey: true,
                        children: [
                          Expanded(child: _formAlani(ilController, 'İl')),
                          const SizedBox(width: 10),
                          Expanded(child: _formAlani(ilceController, 'İlçe')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _formAlani(riskController, 'Risk Limiti', sayisal: true),
                      const SizedBox(height: 10),
                      _formAlani(notlarController, 'Notlar', maxLines: 3),
                      SwitchListTile(
                        title: const Text('Aktif Cari'),
                        value: aktif,
                        onChanged: (deger) {
                          setDialogState(() => aktif = deger);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('İptal'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Kaydet'),
                  onPressed: () {
                    Navigator.pop(dialogContext, {
                      'cari_tipi': cariTipi,
                      'unvan': unvanController.text.trim(),
                      'yetkili': yetkiliController.text.trim(),
                      'telefon': telefonController.text.trim(),
                      'eposta': epostaController.text.trim(),
                      'vergi_no': vergiNoController.text.trim(),
                      'vergi_dairesi': vergiDairesiController.text.trim(),
                      'adres': adresController.text.trim(),
                      'il': ilController.text.trim(),
                      'ilce': ilceController.text.trim(),
                      'risk_limiti': _sayi(riskController.text),
                      'aktif': aktif,
                      'fiyat_tipi': fiyatTipi,
                      'notlar': notlarController.text.trim(),
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );

    unvanController.dispose();
    yetkiliController.dispose();
    telefonController.dispose();
    epostaController.dispose();
    vergiNoController.dispose();
    vergiDairesiController.dispose();
    adresController.dispose();
    ilController.dispose();
    ilceController.dispose();
    riskController.dispose();
    notlarController.dispose();

    if (sonuc == null) return;
    if (_metin(sonuc['unvan']).isEmpty) {
      _mesaj('Cari ünvanı boş bırakılamaz.', Colors.orange);
      return;
    }

    setState(() => _kaydediliyor = true);

    try {
      if (cari == null) {
        await SupabaseService.supabase.from('cariler').insert({
          ...sonuc,
          'bakiye': 0,
        });
      } else {
        await SupabaseService.supabase
            .from('cariler')
            .update(sonuc)
            .eq('cari_id', cari['cari_id']);
      }

      if (!mounted) return;
      _mesaj(
        cari == null
            ? 'Cari başarıyla oluşturuldu.'
            : 'Cari başarıyla güncellendi.',
        Colors.green,
      );
      await _carileriYukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj('Cari kaydedilemedi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  Widget _formAlani(
    TextEditingController controller,
    String etiket, {
    int maxLines = 1,
    bool sayisal = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: sayisal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: etiket,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _cariDetayiniGoster(Map<String, dynamic> cari) async {
    List<Map<String, dynamic>> hareketler = [];
    try {
      final response = await SayfaliVeriService.tumunuGetir(
        (baslangic, bitis) => SupabaseService.supabase
            .from('cari_hareket')
            .select(
              'hareket_id, cari_id, tarih, islem_tipi, belge_no, '
              'borc, alacak, aciklama, kullanici',
            )
            .eq('cari_id', cari['cari_id'])
            .order('tarih', ascending: false)
            .range(baslangic, bitis),
      );
      hareketler = List<Map<String, dynamic>>.from(response);
      hareketler = await CariEkstreService.belgeBilgileriniTamamla(hareketler);
      hareketler = CariEkstreService.kronolojikHareketler(hareketler);
    } catch (e) {
      if (!mounted) return;
      _mesaj('Cari hareketleri yüklenemedi: $e', Colors.red);
      return;
    }

    if (!mounted) return;

    final bakiye = _sayi(cari['bakiye']);
    final toplamBorc = hareketler.fold<double>(
      0,
      (toplam, hareket) => toplam + CariEkstreService.gosterimBorc(hareket),
    );
    final toplamAlacak = hareketler.fold<double>(
      0,
      (toplam, hareket) => toplam + CariEkstreService.gosterimAlacak(hareket),
    );
    final ekstreBakiye = hareketler.isEmpty
        ? 0.0
        : _sayi(hareketler.last['_ekstre_bakiye']);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final mobil = MobilUyum.telefon(dialogContext);

        return AlertDialog(
          title: MobilYatayRow(
            mobilDikey: true,
            children: [
              Expanded(child: Text(_metin(cari['unvan']))),
              IconButton(
                tooltip: 'Düzenle',
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _cariFormu(cari: cari);
                },
                icon: const Icon(Icons.edit),
              ),
            ],
          ),
          content: MobilDialogIcerik(
            width: 1180,
            height: 720,
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 10,
                      children: [
                        _detayBilgisi('Cari Tipi', _metin(cari['cari_tipi'])),
                        _detayBilgisi(
                          'Telefon',
                          _metin(cari['telefon']).isEmpty
                              ? '-'
                              : _metin(cari['telefon']),
                        ),
                        _detayBilgisi(
                          'Risk Limiti',
                          _para(cari['risk_limiti']),
                        ),
                        _detayBilgisi(
                          'Son Alış',
                          _tarih(cari['son_alis_tarihi']),
                        ),
                        _detayBilgisi(
                          'Son Satış',
                          _tarih(cari['son_satis_tarihi']),
                        ),
                        _detayBilgisi(
                          'Bakiye',
                          _para(bakiye.abs()),
                          renk: _bakiyeRengi(cari),
                        ),
                        _detayBilgisi(
                          'Durum',
                          _bakiyeDurumu(cari),
                          renk: _bakiyeRengi(cari),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const MobilYatayRow(
                  children: [
                    Text(
                      'CARİ HAREKETLER',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.touch_app, size: 16, color: Colors.grey),
                    SizedBox(width: 5),
                    Text(
                      'Detay için satıra tıklayın',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: hareketler.isEmpty
                      ? const Center(child: Text('Cari hareket bulunamadı.'))
                      : mobil
                      ? ListView.separated(
                          itemCount: hareketler.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final hareket = hareketler[index];
                            final borc = CariEkstreService.gosterimBorc(
                              hareket,
                            );
                            final alacak = CariEkstreService.gosterimAlacak(
                              hareket,
                            );
                            final satirBakiye = _sayi(
                              hareket['_ekstre_bakiye'],
                            );
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                isThreeLine: true,
                                title: Text(
                                  CariEkstreService.islemTuru(hareket),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${CariEkstreService.tarih(hareket['tarih'])}\n'
                                  'Belge: ${CariEkstreService.faturaNo(hareket)}\n'
                                  'Borç: ${borc == 0 ? '-' : _para(borc)} • '
                                  'Alacak: ${alacak == 0 ? '-' : _para(alacak)}\n'
                                  '${_metin(hareket['aciklama'])}',
                                ),
                                trailing: Text(
                                  CariEkstreService.bakiyeMetni(satirBakiye),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () async {
                                  final detayHareket =
                                      Map<String, dynamic>.from(hareket);
                                  detayHareket['cari_id'] = cari['cari_id'];
                                  await StokBelgeDetayDialog.ac(
                                    dialogContext,
                                    detayHareket,
                                  );
                                },
                              ),
                            );
                          },
                        )
                      : SingleChildScrollView(
                          child: MobilTablo(
                            child: DataTable(
                              showCheckboxColumn: false,
                              columnSpacing: 28,
                              headingRowHeight: 48,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 66,
                              columns: const [
                                DataColumn(label: Text('Tarih')),
                                DataColumn(label: Text('İşlem Türü')),
                                DataColumn(label: Text('Fatura No')),
                                DataColumn(label: Text('Açıklama')),
                                DataColumn(label: Text('Borç')),
                                DataColumn(label: Text('Alacak')),
                                DataColumn(label: Text('Bakiye')),
                              ],
                              rows: hareketler.map((hareket) {
                                final borc = CariEkstreService.gosterimBorc(
                                  hareket,
                                );
                                final alacak = CariEkstreService.gosterimAlacak(
                                  hareket,
                                );
                                final bakiye = _sayi(hareket['_ekstre_bakiye']);
                                return DataRow(
                                  onSelectChanged: (_) async {
                                    final detayHareket =
                                        Map<String, dynamic>.from(hareket);
                                    detayHareket['cari_id'] = cari['cari_id'];

                                    await StokBelgeDetayDialog.ac(
                                      dialogContext,
                                      detayHareket,
                                    );
                                  },
                                  cells: [
                                    DataCell(
                                      Text(
                                        CariEkstreService.tarih(
                                          hareket['tarih'],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        CariEkstreService.islemTuru(hareket),
                                      ),
                                    ),
                                    DataCell(
                                      Text(CariEkstreService.faturaNo(hareket)),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 280,
                                        child: Text(
                                          _metin(hareket['aciklama']),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(borc == 0 ? '-' : _para(borc)),
                                    ),
                                    DataCell(
                                      Text(alacak == 0 ? '-' : _para(alacak)),
                                    ),
                                    DataCell(
                                      Text(
                                        CariEkstreService.bakiyeMetni(bakiye),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: bakiye > 0
                                              ? Colors.red.shade700
                                              : bakiye < 0
                                              ? Colors.green.shade700
                                              : Colors.grey.shade700,
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
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 34,
                    runSpacing: 10,
                    children: [
                      _ekstreOzet(
                        'Toplam Borç',
                        _para(toplamBorc),
                        Colors.red.shade700,
                      ),
                      _ekstreOzet(
                        'Toplam Alacak',
                        _para(toplamAlacak),
                        Colors.green.shade700,
                      ),
                      _ekstreOzet(
                        'Son Bakiye',
                        CariEkstreService.bakiyeMetni(ekstreBakiye),
                        ekstreBakiye > 0
                            ? Colors.red.shade700
                            : ekstreBakiye < 0
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await CariEkstreService.paylas(
                    cari: cari,
                    hareketler: hareketler,
                  );
                } catch (e) {
                  if (mounted) _mesaj('Ekstre oluşturulamadı: $e', Colors.red);
                }
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF / Paylaş'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await CariEkstreService.yazdir(
                    cari: cari,
                    hareketler: hareketler,
                  );
                } catch (e) {
                  if (mounted) _mesaj('Ekstre yazdırılamadı: $e', Colors.red);
                }
              },
              icon: const Icon(Icons.print_rounded),
              label: const Text('Yazdır'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final sonuc = await CariEkstreService.excelAktar(
                    cari: cari,
                    hareketler: hareketler,
                  );
                  if (mounted) _mesaj(sonuc, Colors.green);
                } catch (e) {
                  if (mounted) _mesaj('Excel aktarılamadı: $e', Colors.red);
                }
              },
              icon: const Icon(Icons.table_view_rounded),
              label: const Text('Excel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  Widget _ekstreOzet(String baslik, String deger, Color renk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          baslik,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          deger,
          style: TextStyle(
            color: renk,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _detayBilgisi(String baslik, String deger, {Color? renk}) {
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
          Text(
            deger.isEmpty ? '-' : deger,
            style: TextStyle(fontWeight: FontWeight.bold, color: renk),
          ),
        ],
      ),
    );
  }

  Future<void> _cariyiPasifeAl(Map<String, dynamic> cari) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cariyi pasife al'),
          content: Text(
            '${_metin(cari['unvan'])}\n\nBu cari pasif duruma alınsın mı?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pasife Al'),
            ),
          ],
        );
      },
    );

    if (onay != true) return;

    try {
      await SupabaseService.supabase
          .from('cariler')
          .update({'aktif': false})
          .eq('cari_id', cari['cari_id']);

      if (!mounted) return;
      _mesaj('Cari pasife alındı.', Colors.green);
      await _carileriYukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj('Cari pasife alınamadı: $e', Colors.red);
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
          padding: const EdgeInsets.all(14),
          child: MobilYatayRow(
            mobilDikey: true,
            children: [
              CircleAvatar(
                backgroundColor: renk.withOpacity(0.15),
                child: Icon(ikon, color: renk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deger,
                      style: TextStyle(
                        color: renk,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
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

  Widget _mobilCariOzet({
    required String baslik,
    required String deger,
    required IconData ikon,
    required Color renk,
  }) {
    return Expanded(
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: renk.withOpacity(0.20)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: renk.withOpacity(0.12),
              child: Icon(ikon, color: renk, size: 16),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 9.5),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      deger,
                      maxLines: 1,
                      style: TextStyle(
                        color: renk,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cariKarti(Map<String, dynamic> cari) {
    final unvan = _metin(cari['unvan']);
    final bakiye = _sayi(cari['bakiye']);
    final ilkHarf = unvan.isEmpty ? '?' : unvan.substring(0, 1).toUpperCase();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _cariDetayiniGoster(cari),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: MobilYatayRow(
            mobilDikey: true,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  ilkHarf,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unvan,
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
                        Text('Tip: ${_metin(cari['cari_tipi'])}'),
                        Text(
                          'Telefon: ${_metin(cari['telefon']).isEmpty ? '-' : _metin(cari['telefon'])}',
                        ),
                        Text('Son Alış: ${_tarih(cari['son_alis_tarihi'])}'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _para(bakiye.abs()),
                      style: TextStyle(
                        color: _bakiyeRengi(cari),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bakiyeDurumu(cari),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _bakiyeRengi(cari),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _kaydediliyor ? null : () => _cariFormu(cari: cari),
                icon: const Icon(Icons.edit),
                label: const Text('Düzelt'),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'İşlemler',
                onSelected: (deger) {
                  if (deger == 'detay') {
                    _cariDetayiniGoster(cari);
                  } else if (deger == 'duzenle') {
                    _cariFormu(cari: cari);
                  } else if (deger == 'pasif') {
                    _cariyiPasifeAl(cari);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'detay',
                    child: ListTile(
                      leading: Icon(Icons.visibility),
                      title: Text('Detay'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'duzenle',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Düzenle'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pasif',
                    child: ListTile(
                      leading: Icon(Icons.block, color: Colors.red),
                      title: Text('Pasife Al'),
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

  @override
  Widget build(BuildContext context) {
    final mobil = MobilUyum.telefon(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'CARİ YÖNETİMİ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          MobilAppBarActions(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: _kaydediliyor ? null : () => _cariFormu(),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Yeni Cari Ekle'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Yenile',
                onPressed: _kaydediliyor ? null : _carileriYukle,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _kaydediliyor ? null : () => _cariFormu(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Yeni Cari Ekle'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(mobil ? 8 : 12, mobil ? 6 : 10, mobil ? 8 : 12, 4),
            child: mobil
                ? Row(
                    children: [
                      _mobilCariOzet(
                        baslik: 'Aktif',
                        deger: _aktifCariSayisi.toString(),
                        ikon: Icons.people,
                        renk: Colors.blue,
                      ),
                      const SizedBox(width: 5),
                      _mobilCariOzet(
                        baslik: 'Alacaklıyız',
                        deger: _para(_toplamCariAlacagimiz),
                        ikon: Icons.trending_up,
                        renk: Colors.green,
                      ),
                      const SizedBox(width: 5),
                      _mobilCariOzet(
                        baslik: 'Borçluyuz',
                        deger: _para(_toplamCariBorcumuz),
                        ikon: Icons.trending_down,
                        renk: Colors.red,
                      ),
                    ],
                  )
                : MobilYatayRow(
                    mobilDikey: true,
                    minWidth: 760,
                    children: [
                      _ozetKarti(
                        baslik: 'Aktif Cari',
                        deger: _aktifCariSayisi.toString(),
                        ikon: Icons.people,
                        renk: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _ozetKarti(
                        baslik: 'ALACAKLIYIZ',
                        deger: _para(_toplamCariAlacagimiz),
                        ikon: Icons.trending_up,
                        renk: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _ozetKarti(
                        baslik: 'BORÇLUYUZ',
                        deger: _para(_toplamCariBorcumuz),
                        ikon: Icons.trending_down,
                        renk: Colors.red,
                      ),
                    ],
                  ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: MobilYatayRow(
              mobilDikey: true,
              children: [
                Expanded(
                  child: TextField(
                    controller: _aramaController,
                    decoration: InputDecoration(
                      hintText: 'Cari ünvanı, tipi, yetkili, telefon, şehir...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _aramaController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Temizle',
                              onPressed: _aramaController.clear,
                              icon: const Icon(Icons.clear),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _tipFiltresi,
                  items: const [
                    DropdownMenuItem(value: 'TÜMÜ', child: Text('Tüm Cariler')),
                    DropdownMenuItem(
                      value: 'MÜŞTERİ',
                      child: Text('Müşteriler'),
                    ),
                    DropdownMenuItem(
                      value: 'TEDARİKÇİ',
                      child: Text('Tedarikçiler'),
                    ),
                    DropdownMenuItem(value: 'KARMA', child: Text('Karma')),
                  ],
                  onChanged: (deger) {
                    if (deger == null) return;
                    setState(() => _tipFiltresi = deger);
                    _filtrele();
                  },
                ),
                const SizedBox(width: 10),
                if (!mobil)
                  ElevatedButton.icon(
                    onPressed: _kaydediliyor ? null : () => _cariFormu(),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Yeni Cari'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _gorunenCariler.isEmpty
                ? const Center(
                    child: Text(
                      'Cari bulunamadı.',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _carileriYukle,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _gorunenCariler.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _cariKarti(_gorunenCariler[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
