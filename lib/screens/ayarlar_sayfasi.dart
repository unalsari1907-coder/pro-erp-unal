import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/supabase_service.dart';
import '../services/kimlik_dogrulama_service.dart';
import 'islem_loglari_sayfasi.dart';
import 'kritik_stok_siparis_oneri_sayfasi.dart';
import 'toplu_fiyat_guncelle_sayfasi.dart';
import 'kullanici_yetki_sayfasi.dart';
import 'vade_takip_sayfasi.dart';
import 'firma_ayarlari_sayfasi.dart';
import 'yedekleme_sayfasi.dart';
import 'giris_guvenligi_sayfasi.dart';

class AyarlarSayfasi extends StatefulWidget {
  const AyarlarSayfasi({super.key});

  @override
  State<AyarlarSayfasi> createState() => _AyarlarSayfasiState();
}

class _AyarlarSayfasiState extends State<AyarlarSayfasi> {
  bool yukleniyor = false;

  Future<void> baglantiyiTestEt() async {
    setState(() => yukleniyor = true);
    try {
      await SupabaseService.supabase.from('stoklar').select('stok_id').limit(1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase bağlantısı başarılı! Veritabanı aktif.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bağlantı Hatası: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => yukleniyor = false);
    }
  }


  Future<void> _sistemdenCik() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sistemden Çıkış'),
        content: const Text('Oturumu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.logout), label: const Text('Çıkış Yap')),
        ],
      ),
    );
    if (onay != true) return;
    await KimlikDogrulamaService.cikisYap();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  }

  void _ac(Widget sayfa) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => sayfa));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ÜNAL YEDEK PARÇA • Sistem Ayarları'), centerTitle: true),
      body: yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Yönetim ve Güvenlik', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 10),
                _kart(Icons.admin_panel_settings, 'Kullanıcı / Yetki Yönetimi', 'Yönetici, satış, depo, muhasebe ve izleme rolleri', () => _ac(KullaniciYetkiSayfasi())),
                _kart(Icons.lock_person_rounded, 'Giriş Güvenliği', 'Supabase e-posta/şifre girişini güvenli biçimde etkinleştir', () => _ac(const GirisGuvenligiSayfasi())),
                _kart(Icons.history, 'İşlem Geçmişi / Log', 'Stok, cari, fatura ve hareketlerde kim neyi değiştirdi?', () => _ac(const IslemLoglariSayfasi())),
                const Divider(height: 30),
                const Text('Stok ve Fiyat Yönetimi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 10),
                _kart(Icons.warning_amber_rounded, 'Kritik Stok / Sipariş Önerisi', 'Minimum stok altındaki ürünler ve önerilen sipariş miktarı', () => _ac(const KritikStokSiparisOneriSayfasi())),
                _kart(Icons.percent, 'Toplu Fiyat Güncelleme', 'Marka veya grup bazında alış/satış fiyatlarını yüzdeyle değiştir', () => _ac(const TopluFiyatGuncelleSayfasi())),
                _kart(Icons.event_busy_rounded, 'Vade / Alacak - Borç Takibi', 'Vadesi geçen satış alacakları ve alış borçları', () => _ac(const VadeTakipSayfasi())),
                _kart(Icons.business_rounded, 'Firma / Çıktı Ayarları', 'Logo, adres, iletişim, vergi ve IBAN bilgileri', () => _ac(const FirmaAyarlariSayfasi())),
                const Divider(height: 30),
                const Text('Veritabanı ve Sunucu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 10),
                _kart(Icons.backup_rounded, 'Yedekleme / Geri Yükleme', 'Tam JSON yedek al, doğrula ve geri yükle', () => _ac(const YedeklemeSayfasi())),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_done, color: Colors.green),
                    title: const Text('Supabase Durumu'),
                    subtitle: const Text('Veritabanı bağlantısını kontrol et'),
                    trailing: TextButton(onPressed: baglantiyiTestEt, child: const Text('Test Et')),
                  ),
                ),
                const Divider(height: 30),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.red),
                    title: const Text('Sistemden Çıkış', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Mevcut kullanıcı oturumunu güvenli şekilde kapat'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _sistemdenCik,
                  ),
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Sürüm'),
                    subtitle: Text('${AppConfig.appName} v${AppConfig.version} - Kurumsal Yedek Parça ERP'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _kart(IconData ikon, String baslik, String aciklama, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(ikon, color: Colors.blueGrey.shade700),
        title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(aciklama),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
