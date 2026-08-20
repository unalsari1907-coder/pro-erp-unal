// lib/screens/sayim_screen.dart

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/yetki_service.dart';

class SayimScreen extends StatefulWidget {
  const SayimScreen({super.key});

  @override
  State<SayimScreen> createState() => _SayimScreenState();
}

class _SayimScreenState extends State<SayimScreen> {
  final TextEditingController _aramaController = TextEditingController();

  bool _yukleniyor = true;
  bool _kaydediliyor = false;

  int? _depoId;

  List<Map<String, dynamic>> _depolar = [];
  List<Map<String, dynamic>> _tumStoklar = [];
  List<Map<String, dynamic>> _gorunenStoklar = [];

  final Map<int, TextEditingController> _sayimController = {};

  @override
  void initState() {
    super.initState();
    _aramaController.addListener(_filtrele);
    _ilkYukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    for (final controller in _sayimController.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _sayi(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(',', '.') ?? '0',
        ) ??
        0.0;
  }

  String _miktar(dynamic value) {
    final n = _sayi(value);
    return n == n.roundToDouble()
        ? n.toStringAsFixed(0)
        : n.toStringAsFixed(2);
  }

  String _metin(dynamic value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? '-' : s;
  }

  Future<void> _ilkYukle() async {
    setState(() => _yukleniyor = true);

    try {
      final depolar = await SupabaseService.depolariGetir();

      final aktif = depolar.where((e) {
        final aktifMi = e['aktif'] == null || e['aktif'] == true;
        final tip = (e['depo_tipi']?.toString() ?? '').toUpperCase();
        return aktifMi && tip != 'TRANSIT';
      }).toList();

      if (!mounted) return;

      setState(() {
        _depolar = aktif;
        _depoId = aktif.isEmpty
            ? null
            : int.tryParse(aktif.first['depo_id'].toString());
      });

      await _depoStoklariniYukle();
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _mesaj('Sayım ekranı yüklenemedi: $e', Colors.red);
    }
  }

  Future<void> _depoStoklariniYukle() async {
    final depoId = _depoId;
    if (depoId == null) {
      if (mounted) setState(() => _yukleniyor = false);
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      final rows = await SupabaseService.supabase
          .from('v_pro_stok_depo_durumu')
          .select()
          .eq('depo_id', depoId)
          .order('urun_adi');

      final liste = List<Map<String, dynamic>>.from(rows);

      for (final c in _sayimController.values) {
        c.dispose();
      }
      _sayimController.clear();

      for (final item in liste) {
        final stokId = int.tryParse(item['stok_id']?.toString() ?? '');
        if (stokId == null) continue;
        _sayimController[stokId] = TextEditingController(
          text: _miktar(item['miktar']),
        );
      }

      if (!mounted) return;

      setState(() {
        _tumStoklar = liste;
        _gorunenStoklar = liste;
        _yukleniyor = false;
      });

      _filtrele();
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _mesaj('Depo stokları yüklenemedi: $e', Colors.red);
    }
  }

  void _filtrele() {
    final q = _aramaController.text.trim().toLowerCase();

    if (!mounted) return;

    setState(() {
      _gorunenStoklar = _tumStoklar.where((item) {
        if (q.isEmpty) return true;

        final metin = [
          item['urun_adi'],
          item['uretici_kodu'],
          item['oem_no'],
          item['marka'],
          item['raf'],
        ].map((e) => e?.toString().toLowerCase() ?? '').join(' ');

        return metin.contains(q);
      }).toList();
    });
  }

  Future<void> _kaydet() async {
    final depoId = _depoId;
    if (depoId == null || _kaydediliyor) return;

    final degisenler = <Map<String, dynamic>>[];

    for (final item in _tumStoklar) {
      final stokId = int.tryParse(item['stok_id']?.toString() ?? '');
      if (stokId == null) continue;

      final sistem = _sayi(item['miktar']);
      final sayilan = _sayi(_sayimController[stokId]?.text);

      if ((sistem - sayilan).abs() > 0.000001) {
        degisenler.add({
          'stok_id': stokId,
          'sistem': sistem,
          'sayilan': sayilan,
        });
      }
    }

    if (degisenler.isEmpty) {
      _mesaj('Fark bulunan ürün yok.', Colors.blueGrey);
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sayımı Onayla'),
        content: Text(
          '${degisenler.length} üründe stok farkı var.\n'
          'Farklar stok hareketine işlensin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (onay != true) return;

    setState(() => _kaydediliyor = true);

    try {
      for (final item in degisenler) {
        await SupabaseService.supabase.rpc(
          'stok_sayim_duzelt',
          params: {
            'p_stok_id': item['stok_id'],
            'p_depo_id': depoId,
            'p_sayilan_miktar': item['sayilan'],
            'p_kullanici': YetkiService.aktifKullanici,
            'p_aciklama': 'Stok sayım düzeltmesi',
          },
        );
      }

      if (!mounted) return;
      _mesaj('Sayım farkları kaydedildi.', Colors.green);
      await _depoStoklariniYukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj(
        'Sayım kaydedilemedi. SQL paketindeki stok_sayim_duzelt fonksiyonunu '
        'çalıştırdığınızdan emin olun.\n$e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _kaydediliyor = false);
      }
    }
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: renk,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'STOK SAYIMI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: _kaydediliyor ? null : _kaydet,
            icon: const Icon(Icons.save_rounded),
            label: Text(_kaydediliyor ? 'Kaydediliyor...' : 'Sayımı Kaydet'),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _yukleniyor ? null : _depoStoklariniYukle,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<int>(
                    value: _depoId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Depo',
                      border: OutlineInputBorder(),
                    ),
                    items: _depolar.map((depo) {
                      return DropdownMenuItem<int>(
                        value: int.tryParse(depo['depo_id'].toString()),
                        child: Text(
                          '${_metin(depo['depo_adi'])} '
                          '(${_metin(depo['depo_tipi'])})',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      setState(() => _depoId = value);
                      await _depoStoklariniYukle();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _aramaController,
                    decoration: InputDecoration(
                      hintText: 'Ürün, üretici kodu, OEM, marka, RAF ara...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _aramaController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _aramaController.clear,
                              icon: const Icon(Icons.clear_rounded),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _gorunenStoklar.isEmpty
                    ? const Center(
                        child: Text(
                          'Bu depoda sayılacak stok bulunamadı.',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _gorunenStoklar.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (_, index) {
                          final item = _gorunenStoklar[index];
                          final stokId = int.tryParse(
                                item['stok_id']?.toString() ?? '',
                              ) ??
                              0;
                          final sistem = _sayi(item['miktar']);
                          final controller = _sayimController[stokId];

                          return Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    child: Icon(Icons.inventory_2_outlined),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _metin(item['urun_adi']),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Kod: ${_metin(item['uretici_kodu'])} • '
                                          'RAF: ${_metin(item['raf'])}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Sistem',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          _miktar(sistem),
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  SizedBox(
                                    width: 150,
                                    child: TextField(
                                      controller: controller,
                                      textAlign: TextAlign.right,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Sayılan',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
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
