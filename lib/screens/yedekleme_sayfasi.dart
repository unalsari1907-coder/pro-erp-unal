import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/yedekleme_service.dart';

class YedeklemeSayfasi extends StatefulWidget {
  const YedeklemeSayfasi({super.key});
  @override
  State<YedeklemeSayfasi> createState() => _YedeklemeSayfasiState();
}

class _YedeklemeSayfasiState extends State<YedeklemeSayfasi> {
  bool _calisiyor = false;
  String _durum = 'Hazır.';

  Future<void> _yedekAl() async {
    setState(() { _calisiyor = true; _durum = 'Tüm tablolar okunuyor ve yedek hazırlanıyor...'; });
    try {
      final sonuc = await YedeklemeService.jsonYedegiAl();
      if (!mounted) return;
      setState(() => _durum = '${sonuc.tabloSayisi} tablo • ${sonuc.kayitSayisi} kayıt yedeklendi.\nDosya: ${sonuc.dosya}${sonuc.atlananlar.isEmpty ? '' : '\nAtlanan tablolar: ${sonuc.atlananlar.join(', ')}'}');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tam PRO ERP yedeği oluşturuldu.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) setState(() => _durum = 'Yedekleme başarısız: $e');
    } finally { if (mounted) setState(() => _calisiyor = false); }
  }

  Future<void> _geriYukle() async {
    final sonuc = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (sonuc == null || sonuc.files.isEmpty || sonuc.files.single.bytes == null) return;
    final bytes = sonuc.files.single.bytes!;
    try {
      final bilgi = YedeklemeService.yedegiDogrula(bytes);
      if (!mounted) return;
      final onay = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('YEDEĞİ GERİ YÜKLE'),
        content: Text('Dosya doğrulandı.\nFormat: ${bilgi['format']}\nOluşturma: ${bilgi['olusturma_zamani'] ?? '-'}\n\nMevcut kayıtlar silinmez; aynı anahtarlar güncellenir, eksik kayıtlar eklenir. İşlem öncesi ayrıca güncel yedek almanız önerilir.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Geri Yükle'))],
      ));
      if (onay != true) return;
      setState(() { _calisiyor = true; _durum = 'Yedek geri yükleniyor...'; });
      final geri = await YedeklemeService.jsonYedegiGeriYukle(bytes);
      if (!mounted) return;
      setState(() => _durum = '${geri.tabloSayisi} tablo • ${geri.kayitSayisi} kayıt geri yüklendi.${geri.hataliTablolar.isEmpty ? '' : '\nHata alınan tablolar: ${geri.hataliTablolar.join(', ')}'}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(geri.hataliTablolar.isEmpty ? 'Geri yükleme tamamlandı.' : 'Geri yükleme kısmen tamamlandı.'), backgroundColor: geri.hataliTablolar.isEmpty ? Colors.green : Colors.orange));
    } catch (e) {
      if (mounted) setState(() => _durum = 'Geri yükleme başarısız: $e');
    } finally { if (mounted) setState(() => _calisiyor = false); }
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(title: const Text('YEDEKLEME / GERİ YÜKLEME')),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: SizedBox(width: mobil ? double.infinity : 760, child: Card(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.shield_outlined, size: 64, color: Colors.blue),
          const SizedBox(height: 14),
          const Text('Tam ERP Veri Koruma', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Stok, cari, satış, alış, sipariş, irsaliye, iade, finans, kullanıcı ve kurumsal modül tablolarını JSON dosyasına yedekler. Yedek dosyasını doğrulayıp geri yükleyebilir.', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          SelectableText(_durum, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.center, children: [
            ElevatedButton.icon(onPressed: _calisiyor ? null : _yedekAl, icon: const Icon(Icons.download_rounded), label: const Text('Tam Yedek Al')),
            OutlinedButton.icon(onPressed: _calisiyor ? null : _geriYukle, icon: const Icon(Icons.restore_rounded), label: const Text('Yedekten Geri Yükle')),
          ]),
          if (_calisiyor) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
        ]),
      ))))),
    );
  }
}
