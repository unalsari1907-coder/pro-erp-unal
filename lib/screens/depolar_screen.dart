// lib/screens/depolar_screen.dart

import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class DepolarScreen extends StatefulWidget {
  const DepolarScreen({super.key});

  @override
  State<DepolarScreen> createState() => _DepolarScreenState();
}

class _DepolarScreenState extends State<DepolarScreen> {
  bool _yukleniyor = true;
  final TextEditingController _aramaController = TextEditingController();

  List<Map<String, dynamic>> _tum = [];
  List<Map<String, dynamic>> _gorunen = [];

  @override
  void initState() {
    super.initState();
    _aramaController.addListener(_filtrele);
    _yukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  String _m(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? '-' : s;
  }

  int _i(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  Color _tipRengi(String tip) {
    switch (tip.toUpperCase()) {
      case 'NORMAL':
        return Colors.green;
      case 'IADE':
        return Colors.orange;
      case 'HASARLI':
        return Colors.red;
      case 'TRANSIT':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _tipIkonu(String tip) {
    switch (tip.toUpperCase()) {
      case 'NORMAL':
        return Icons.warehouse_rounded;
      case 'IADE':
        return Icons.assignment_return_rounded;
      case 'HASARLI':
        return Icons.warning_amber_rounded;
      case 'TRANSIT':
        return Icons.local_shipping_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);

    try {
      final depolar = await SupabaseService.depolariGetir();

      if (!mounted) return;

      setState(() {
        _tum = depolar;
        _gorunen = depolar;
        _yukleniyor = false;
      });

      _filtrele();
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _mesaj('Depolar yüklenemedi: $e', Colors.red);
    }
  }

  void _filtrele() {
    final q = _aramaController.text.toLowerCase().trim();

    setState(() {
      _gorunen = _tum.where((e) {
        if (q.isEmpty) return true;
        final metin = [
          e['depo_kodu'],
          e['depo_adi'],
          e['depo_tipi'],
          e['aciklama'],
        ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
        return metin.contains(q);
      }).toList();
    });
  }

  Future<void> _depoFormu({Map<String, dynamic>? mevcut}) async {
    final kod = TextEditingController(text: mevcut?['depo_kodu']?.toString() ?? '');
    final ad = TextEditingController(text: mevcut?['depo_adi']?.toString() ?? '');
    final aciklama = TextEditingController(text: mevcut?['aciklama']?.toString() ?? '');

    String tip = mevcut?['depo_tipi']?.toString() ?? 'NORMAL';
    bool aktif = mevcut?['aktif'] as bool? ?? true;
    bool satilabilir = mevcut?['satilabilir'] as bool? ?? true;

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(mevcut == null ? 'Yeni Depo' : 'Depoyu Düzenle'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: kod,
                      decoration: const InputDecoration(
                        labelText: 'Depo Kodu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ad,
                      decoration: const InputDecoration(
                        labelText: 'Depo Adı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: tip,
                      decoration: const InputDecoration(
                        labelText: 'Depo Tipi',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                        DropdownMenuItem(value: 'IADE', child: Text('İade')),
                        DropdownMenuItem(value: 'HASARLI', child: Text('Hasarlı')),
                        DropdownMenuItem(value: 'TRANSIT', child: Text('Transit')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          tip = v;
                          if (tip != 'NORMAL') satilabilir = false;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: aktif,
                      onChanged: (v) => setDialogState(() => aktif = v),
                      title: const Text('Aktif'),
                    ),
                    SwitchListTile(
                      value: satilabilir,
                      onChanged: tip == 'NORMAL'
                          ? (v) => setDialogState(() => satilabilir = v)
                          : null,
                      title: const Text('Satılabilir'),
                    ),
                    TextField(
                      controller: aciklama,
                      maxLines: 3,
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
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    if (kaydet != true) return;

    if (kod.text.trim().isEmpty || ad.text.trim().isEmpty) {
      _mesaj('Depo kodu ve depo adı zorunludur.', Colors.orange);
      return;
    }

    try {
      await SupabaseService.depoKaydet(
        depoId: mevcut == null ? null : _i(mevcut['depo_id']),
        depoKodu: kod.text.trim(),
        depoAdi: ad.text.trim(),
        depoTipi: tip,
        aktif: aktif,
        satilabilir: satilabilir,
        aciklama: aciklama.text.trim(),
      );

      _mesaj('Depo kaydedildi.', Colors.green);
      await _yukle();
    } catch (e) {
      _mesaj('Depo kaydedilemedi: $e', Colors.red);
    }
  }

  Future<void> _detayGoster(Map<String, dynamic> depo) async {
    final detay = await SupabaseService.depoStoklariniGetir(
      _i(depo['depo_id']),
    );

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${_m(depo['depo_adi'])} - Stoklar'),
          content: SizedBox(
            width: MediaQuery.sizeOf(dialogContext).width < 720 ? MediaQuery.sizeOf(dialogContext).width - 48 : 900,
            height: MediaQuery.sizeOf(dialogContext).width < 720 ? MediaQuery.sizeOf(dialogContext).height * .72 : 560,
            child: detay.isEmpty
                ? const Center(child: Text('Bu depoda stok yok.'))
                : ListView.separated(
                    itemCount: detay.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final item = detay[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.inventory_2_outlined),
                        ),
                        title: Text(_m(item['urun_adi'])),
                        subtitle: Text(
                          'Kod: ${_m(item['uretici_kodu'])} • '
                          'Depo: ${_m(item['depo_adi'])}',
                        ),
                        trailing: Text(
                          '${_m(item['miktar'])} Adet',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  void _mesaj(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DEPOLAR',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _depoFormu(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni Depo'),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _yukleniyor ? null : _yukle,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _aramaController,
              decoration: const InputDecoration(
                hintText: 'Depo ara...',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 380,
                      mainAxisExtent: 190,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _gorunen.length,
                    itemBuilder: (_, index) {
                      final depo = _gorunen[index];
                      final tip = _m(depo['depo_tipi']);
                      final renk = _tipRengi(tip);

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _detayGoster(depo),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: renk.withOpacity(0.12),
                                      child: Icon(_tipIkonu(tip), color: renk),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _m(depo['depo_adi']),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Düzenle',
                                      onPressed: () => _depoFormu(mevcut: depo),
                                      icon: const Icon(Icons.edit_rounded),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text('Kod: ${_m(depo['depo_kodu'])}'),
                                Text('Tip: $tip'),
                                Text(
                                  'Durum: ${depo['aktif'] == true ? 'Aktif' : 'Pasif'}',
                                ),
                                Text(
                                  'Satılabilir: ${depo['satilabilir'] == true ? 'Evet' : 'Hayır'}',
                                ),
                                const Spacer(),
                                Text(
                                  _m(depo['aciklama']),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.grey),
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