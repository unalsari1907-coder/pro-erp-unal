import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../widgets/erp_detay_dialog.dart';

class KritikStokSiparisOneriSayfasi extends StatefulWidget {
  const KritikStokSiparisOneriSayfasi({super.key});

  @override
  State<KritikStokSiparisOneriSayfasi> createState() => _KritikStokSiparisOneriSayfasiState();
}

class _KritikStokSiparisOneriSayfasiState extends State<KritikStokSiparisOneriSayfasi> {
  bool _yukleniyor = true;
  List<Map<String, dynamic>> _liste = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    if (mounted) setState(() => _yukleniyor = true);
    try {
      final response = await SupabaseService.supabase
          .from('v_kritik_stok_siparis_oneri')
          .select()
          .order('eksik_miktar', ascending: false);
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(response);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kritik stoklar yüklenemedi: $e')));
    }
  }

  String _n(dynamic v) => (double.tryParse(v?.toString() ?? '0') ?? 0).toStringAsFixed(0);

  void _tumunuKopyala() {
    final metin = _liste.map((x) => '${x['uretici_kodu'] ?? '-'}\t${x['urun_adi'] ?? '-'}\tMevcut:${_n(x['mevcut_stok'])}\tMin:${_n(x['min_stok'])}\tÖneri:${_n(x['onerilen_siparis'])}').join('\n');
    Clipboard.setData(ClipboardData(text: metin));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sipariş öneri listesi panoya kopyalandı.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KRİTİK STOK / SİPARİŞ ÖNERİSİ'),
        actions: [
          TextButton.icon(onPressed: _liste.isEmpty ? null : _tumunuKopyala, icon: const Icon(Icons.copy_all), label: const Text('Tümünü Kopyala')),
          IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _liste.isEmpty
              ? const Center(child: Text('Minimum stok altında ürün yok.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _liste.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final x = _liste[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.warning_amber_rounded)),
                        title: Text((x['urun_adi'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Kod: ${x['uretici_kodu'] ?? '-'}  •  Marka: ${x['marka'] ?? '-'}  •  RAF: ${x['raf'] ?? '-'}'),
                        onTap: () => ErpDetayDialog.goster(
                          context,
                          baslik: 'Kritik Stok • Ürün Detayı',
                          altBaslik: 'Stok seviyesi ve sipariş önerisi',
                          veri: x,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _kut('Mevcut', _n(x['mevcut_stok']), Colors.red),
                            const SizedBox(width: 8),
                            _kut('Min.', _n(x['min_stok']), Colors.orange),
                            const SizedBox(width: 8),
                            _kut('Sipariş', _n(x['onerilen_siparis']), Colors.blue),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _kut(String baslik, String deger, Color renk) => Container(
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(color: renk.withOpacity(.08), border: Border.all(color: renk.withOpacity(.4)), borderRadius: BorderRadius.circular(8)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [Text(baslik, style: TextStyle(fontSize: 11, color: renk)), Text(deger, style: TextStyle(fontWeight: FontWeight.bold, color: renk))]),
      );
}