import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/yetki_service.dart';

class TopluFiyatGuncelleSayfasi extends StatefulWidget {
  const TopluFiyatGuncelleSayfasi({super.key});

  @override
  State<TopluFiyatGuncelleSayfasi> createState() => _TopluFiyatGuncelleSayfasiState();
}

class _TopluFiyatGuncelleSayfasiState extends State<TopluFiyatGuncelleSayfasi> {
  final _oranCtrl = TextEditingController(text: '10');
  final _markaCtrl = TextEditingController();
  final _grupCtrl = TextEditingController();
  String _alan = 'PERAKENDE';
  bool _kaydediliyor = false;

  @override
  void dispose() {
    _oranCtrl.dispose();
    _markaCtrl.dispose();
    _grupCtrl.dispose();
    super.dispose();
  }

  Future<void> _uygula() async {
    final oran = double.tryParse(_oranCtrl.text.replaceAll(',', '.'));
    if (oran == null || oran == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir yüzde girin.')));
      return;
    }
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Toplu Fiyat Güncelleme'),
        content: Text('$_alan fiyatlarına %${oran.toStringAsFixed(2)} değişiklik uygulanacak.\nMarka: ${_markaCtrl.text.trim().isEmpty ? 'TÜMÜ' : _markaCtrl.text.trim()}\nGrup: ${_grupCtrl.text.trim().isEmpty ? 'TÜMÜ' : _grupCtrl.text.trim()}\n\nDevam edilsin mi?'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')), ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Uygula'))],
      ),
    );
    if (onay != true) return;
    setState(() => _kaydediliyor = true);
    try {
      final sonuc = await SupabaseService.supabase.rpc('stok_toplu_fiyat_guncelle', params: {
        'p_fiyat_alani': _alan,
        'p_oran': oran,
        'p_marka': _markaCtrl.text.trim().isEmpty ? null : _markaCtrl.text.trim(),
        'p_grup': _grupCtrl.text.trim().isEmpty ? null : _grupCtrl.text.trim(),
        'p_kullanici': YetkiService.aktifKullanici,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$sonuc stok kartının fiyatı güncellendi.'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Toplu fiyat hatası: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TOPLU FİYAT GÜNCELLEME')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Pozitif oran fiyatı artırır, negatif oran azaltır. Örnek: 10 = %10 artır, -5 = %5 azalt. Marka ve grup boş bırakılırsa tüm stoklara uygulanır.'))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _alan,
                items: const [
                  DropdownMenuItem(value: 'ALIS', child: Text('Alış Fiyatı')),
                  DropdownMenuItem(value: 'PERAKENDE', child: Text('Perakende Satış')),
                  DropdownMenuItem(value: 'TOPTAN', child: Text('Toptan Satış')),
                  DropdownMenuItem(value: 'INDIRIMLI', child: Text('İndirimli Satış')),
                ],
                onChanged: (v) => setState(() => _alan = v ?? 'PERAKENDE'),
                decoration: const InputDecoration(labelText: 'Fiyat Alanı', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(controller: _oranCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Değişim Oranı %', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _markaCtrl, decoration: const InputDecoration(labelText: 'Marka Filtresi (opsiyonel)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _grupCtrl, decoration: const InputDecoration(labelText: 'Grup Filtresi (opsiyonel)', border: OutlineInputBorder())),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: _kaydediliyor ? null : _uygula, icon: _kaydediliyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.percent), label: const Text('Fiyatları Güncelle')),
            ],
          ),
        ),
      ),
    );
  }
}
