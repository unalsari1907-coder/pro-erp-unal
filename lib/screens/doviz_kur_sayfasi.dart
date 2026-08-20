import 'package:flutter/material.dart';

import '../services/doviz_kur_service.dart';

class DovizKurSayfasi extends StatefulWidget {
  const DovizKurSayfasi({super.key});

  @override
  State<DovizKurSayfasi> createState() => _DovizKurSayfasiState();
}

class _DovizKurSayfasiState extends State<DovizKurSayfasi> {
  bool _yukleniyor = true;
  bool _guncelleniyor = false;
  List<Map<String, dynamic>> _kurlar = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  double _sayi(dynamic value) =>
      double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;

  String _kur(dynamic value) => _sayi(value).toStringAsFixed(4);

  String _tarih(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    if (d == null) return value?.toString() ?? '-';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Future<void> _yukle() async {
    if (!mounted) return;
    setState(() => _yukleniyor = true);
    try {
      final liste = await DovizKurService.kurlariGetir();
      if (!mounted) return;
      setState(() => _kurlar = liste);
    } catch (e) {
      if (mounted) _mesaj('Kurlar yüklenemedi: $e', hata: true);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _tcmbGuncelle() async {
    setState(() => _guncelleniyor = true);
    try {
      final sonuc = await DovizKurService.tcmbKurlariniCek();
      if (!mounted) return;
      final adet = sonuc['kaydedilen'] ?? '-';
      _mesaj('TCMB kurları güncellendi. $adet döviz kaydedildi.');
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj(
        'TCMB kurları alınamadı: $e\nEdge Function kurulmadıysa supabase/functions/tcmb-kur-guncelle fonksiyonunu deploy edin.',
        hata: true,
      );
    } finally {
      if (mounted) setState(() => _guncelleniyor = false);
    }
  }

  void _mesaj(String text, {bool hata = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: hata ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _manuelKurDialog() async {
    final kod = TextEditingController(text: 'USD');
    final alis = TextEditingController();
    final satis = TextEditingController();
    final efektifAlis = TextEditingController();
    final efektifSatis = TextEditingController();
    DateTime seciliTarih = DateTime.now();

    try {
      final kaydet = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Manuel Kur Girişi'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: kod,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Döviz Kodu',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(_tarih(seciliTarih.toIso8601String())),
                            onPressed: () async {
                              final t = await showDatePicker(
                                context: dialogContext,
                                initialDate: seciliTarih,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (t != null) setDialogState(() => seciliTarih = t);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _sayiAlani(alis, 'Döviz Alış')),
                        const SizedBox(width: 12),
                        Expanded(child: _sayiAlani(satis, 'Döviz Satış')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _sayiAlani(efektifAlis, 'Efektif Alış')),
                        const SizedBox(width: 12),
                        Expanded(child: _sayiAlani(efektifSatis, 'Efektif Satış')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kaydet')),
            ],
          ),
        ),
      );

      if (kaydet != true) return;
      final a = double.tryParse(alis.text.replaceAll(',', '.'));
      final s = double.tryParse(satis.text.replaceAll(',', '.'));
      if (kod.text.trim().isEmpty || a == null || s == null) {
        _mesaj('Döviz kodu, alış ve satış zorunludur.', hata: true);
        return;
      }
      await DovizKurService.manuelKurKaydet(
        tarih: seciliTarih,
        paraBirimi: kod.text,
        alis: a,
        satis: s,
        efektifAlis: double.tryParse(efektifAlis.text.replaceAll(',', '.')),
        efektifSatis: double.tryParse(efektifSatis.text.replaceAll(',', '.')),
      );
      _mesaj('Manuel kur kaydedildi.');
      await _yukle();
    } finally {
      kod.dispose();
      alis.dispose();
      satis.dispose();
      efektifAlis.dispose();
      efektifSatis.dispose();
    }
  }

  Widget _sayiAlani(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  Map<String, Map<String, dynamic>> get _sonKurlar {
    final map = <String, Map<String, dynamic>>{};
    for (final row in _kurlar) {
      final kod = row['para_birimi']?.toString() ?? '';
      if (kod.isNotEmpty) map.putIfAbsent(kod, () => row);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MediaQuery.of(context).size.width < 720;
    final sonlar = _sonKurlar;
    const kodlar = DovizKurService.varsayilanDovizler;

    return Scaffold(
      backgroundColor: const Color(0xfff4f6f9),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DÖVİZ / KUR YÖNETİMİ', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('TCMB günlük kurları ve kur geçmişi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _guncelleniyor ? null : _tcmbGuncelle,
            icon: _guncelleniyor
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            label: const Text('TCMB Kurlarını Güncelle'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _manuelKurDialog,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Manuel Kur'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: EdgeInsets.all(mobil ? 12 : 20),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: kodlar.map((kod) {
                      final r = sonlar[kod];
                      return SizedBox(
                        width: mobil ? double.infinity : 235,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(child: Text(kod.substring(0, 1))),
                                    const SizedBox(width: 10),
                                    Text(kod, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    Text(r == null ? '-' : _tarih(r['tarih']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                const Divider(height: 24),
                                _kurSatiri('Alış', r == null ? '-' : _kur(r['alis'])),
                                _kurSatiri('Satış', r == null ? '-' : _kur(r['satis'])),
                                const SizedBox(height: 8),
                                Text('Kaynak: ${r?['kaynak'] ?? '-'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('KUR GEÇMİŞİ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Tarih')),
                                DataColumn(label: Text('Döviz')),
                                DataColumn(label: Text('Alış')),
                                DataColumn(label: Text('Satış')),
                                DataColumn(label: Text('Efektif Alış')),
                                DataColumn(label: Text('Efektif Satış')),
                                DataColumn(label: Text('Kaynak')),
                              ],
                              rows: _kurlar.map((r) => DataRow(cells: [
                                DataCell(Text(_tarih(r['tarih']))),
                                DataCell(Text(r['para_birimi']?.toString() ?? '-')),
                                DataCell(Text(_kur(r['alis']))),
                                DataCell(Text(_kur(r['satis']))),
                                DataCell(Text(_kur(r['efektif_alis']))),
                                DataCell(Text(_kur(r['efektif_satis']))),
                                DataCell(Text(r['kaynak']?.toString() ?? '-')),
                              ])).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Not: Belgede kullanılan kur, belge kaydedildiğinde belgeye sabitlenmelidir. Sonraki günlük kur güncellemeleri geçmiş belgenin kurunu değiştirmemelidir.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _kurSatiri(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
            const Spacer(),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );
}
