import 'package:flutter/material.dart';

import '../widgets/mobil_uyum.dart';

import '../services/supabase_service.dart';
import '../services/yetki_service.dart';
import '../services/sayfali_veri_service.dart';

class KasaGunSonuSayfasi extends StatefulWidget {
  const KasaGunSonuSayfasi({super.key});

  @override
  State<KasaGunSonuSayfasi> createState() =>
      _KasaGunSonuSayfasiState();
}

class _KasaGunSonuSayfasiState extends State<KasaGunSonuSayfasi> {
  bool _yukleniyor = true;
  DateTime _tarih = DateTime.now();
  List<Map<String, dynamic>> _kasalar = [];
  Map<int, double> _beklenen = {};
  Map<int, Map<String, dynamic>> _kayitlar = {};

  double _sayi(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(',', '.') ?? '0',
        ) ??
        0;
  }

  String _para(dynamic value) =>
      '${_sayi(value).toStringAsFixed(2)} ₺';

  String get _tarihAnahtari =>
      '${_tarih.year.toString().padLeft(4, '0')}-'
      '${_tarih.month.toString().padLeft(2, '0')}-'
      '${_tarih.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    if (mounted) setState(() => _yukleniyor = true);

    try {
      final kasaResponse = await SupabaseService.supabase
          .from('kasalar')
          .select('kasa_id, kasa_adi, kasa_tipi')
          .order('kasa_adi');

      final kasalar = List<Map<String, dynamic>>.from(kasaResponse);
      final beklenen = <int, double>{};

      final ertesiGun = DateTime(_tarih.year, _tarih.month, _tarih.day + 1);
      final hareketResponse = await SayfaliVeriService.tumunuGetir(
        (baslangic, bitis) => SupabaseService.supabase
            .from('kasa_hareket')
            .select('kasa_id, tip, tutar, tarih')
            .lt('tarih', ertesiGun.toUtc().toIso8601String())
            .order('tarih')
            .range(baslangic, bitis),
      );

      for (final hareket in hareketResponse) {
        final id = int.tryParse(hareket['kasa_id']?.toString() ?? '');
        if (id == null) continue;
        final tip = hareket['tip']
                ?.toString()
                .trim()
                .toUpperCase()
                .replaceAll('İ', 'I') ??
            '';
        final giris = const {
          'GIRIS',
          'TAHSILAT',
          'VIRMAN_GIRIS',
          'TRANSFER_GIRIS',
        }.contains(tip);
        beklenen[id] =
            (beklenen[id] ?? 0) + (giris ? 1 : -1) * _sayi(hareket['tutar']);
      }

      final gunSonuResponse = await SupabaseService.supabase
          .from('erp_kasa_gun_sonu')
          .select()
          .eq('tarih', _tarihAnahtari);

      final kayitlar = <int, Map<String, dynamic>>{};
      for (final kayit
          in List<Map<String, dynamic>>.from(gunSonuResponse)) {
        final id = int.tryParse(kayit['kasa_id']?.toString() ?? '');
        if (id != null) kayitlar[id] = kayit;
      }

      if (!mounted) return;
      setState(() {
        _kasalar = kasalar;
        _beklenen = beklenen;
        _kayitlar = kayitlar;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _mesaj('Kasa gün sonu yüklenemedi: $e', Colors.red);
    }
  }

  Future<void> _tarihSec() async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (secilen == null) return;
    setState(() => _tarih = secilen);
    await _yukle();
  }

  Future<void> _sayimKaydet(Map<String, dynamic> kasa) async {
    final kasaId = int.tryParse(kasa['kasa_id']?.toString() ?? '');
    if (kasaId == null) return;

    final beklenen = _beklenen[kasaId] ?? 0;
    final mevcut = _kayitlar[kasaId];
    final controller = TextEditingController(
      text: _sayi(mevcut?['sayilan_bakiye'] ?? beklenen)
          .toStringAsFixed(2),
    );
    final aciklama = TextEditingController(
      text: mevcut?['aciklama']?.toString() ?? '',
    );

    final sonuc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${kasa['kasa_adi'] ?? '-'} Gün Sonu'),
          content: MobilDialogIcerik(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistem Bakiyesi: ${_para(beklenen)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sayılan / Gerçek Bakiye',
                    suffixText: '₺',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aciklama,
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                final sayilan = double.tryParse(
                  controller.text.replaceAll(',', '.'),
                );
                if (sayilan == null) return;
                Navigator.pop(dialogContext, {
                  'sayilan': sayilan,
                  'aciklama': aciklama.text.trim(),
                });
              },
              child: const Text('Gün Sonunu Kaydet'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    aciklama.dispose();
    if (sonuc == null) return;

    try {
      final sayilan = _sayi(sonuc['sayilan']);
      await SupabaseService.supabase.from('erp_kasa_gun_sonu').upsert(
        {
          'tarih': _tarihAnahtari,
          'kasa_id': kasaId,
          'sistem_bakiyesi': beklenen,
          'sayilan_bakiye': sayilan,
          'fark': sayilan - beklenen,
          'aciklama': sonuc['aciklama'],
          'kullanici': YetkiService.aktifKullanici,
          'kayit_zamani': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'tarih,kasa_id',
      );
      if (!mounted) return;
      _mesaj('Kasa gün sonu kaydedildi.', Colors.green);
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj('Gün sonu kaydedilemedi: $e', Colors.red);
    }
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: renk),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KASA GÜN SONU / MUTABAKAT'),
        actions: [
          MobilAppBarActions(
            children: [
          TextButton.icon(
            onPressed: _tarihSec,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(_tarihAnahtari),
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _yukle,
            icon: const Icon(Icons.refresh_rounded),
          ),
        
            ],
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _kasalar.isEmpty
              ? const Center(child: Text('Kasa/banka hesabı bulunamadı.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _kasalar.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final kasa = _kasalar[index];
                    final id = int.tryParse(
                          kasa['kasa_id']?.toString() ?? '',
                        ) ??
                        0;
                    final beklenen = _beklenen[id] ?? 0;
                    final kayit = _kayitlar[id];
                    final fark = _sayi(kayit?['fark']);
                    final renk = kayit == null
                        ? Colors.orange
                        : fark.abs() < 0.01
                            ? Colors.green
                            : Colors.red;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: renk.withOpacity(0.12),
                          child: Icon(
                            kayit == null
                                ? Icons.pending_actions_rounded
                                : fark.abs() < 0.01
                                    ? Icons.verified_rounded
                                    : Icons.warning_amber_rounded,
                            color: renk,
                          ),
                        ),
                        title: Text(
                          kasa['kasa_adi']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          kayit == null
                              ? 'Gün sonu yapılmadı'
                              : 'Sayılan: ${_para(kayit['sayilan_bakiye'])} • '
                                  'Fark: ${_para(fark)} • '
                                  '${kayit['kullanici'] ?? '-'}',
                        ),
                        trailing: MobilYatayRow(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Sistem: ${_para(beklenen)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => _sayimKaydet(kasa),
                              icon: const Icon(Icons.fact_check_rounded),
                              label: Text(kayit == null ? 'Sayım Yap' : 'Düzelt'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
