import 'package:flutter/material.dart';

import '../services/kimlik_dogrulama_service.dart';
import '../services/supabase_service.dart';
import 'giris_sayfasi.dart';

class GirisGuvenligiSayfasi extends StatefulWidget {
  const GirisGuvenligiSayfasi({super.key});

  @override
  State<GirisGuvenligiSayfasi> createState() => _GirisGuvenligiSayfasiState();
}

class _GirisGuvenligiSayfasiState extends State<GirisGuvenligiSayfasi> {
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    await KimlikDogrulamaService.guvenliGirisAktifMi();
    if (!mounted) return;
    setState(() => _yukleniyor = false);
  }

  Future<void> _yoneticiGirisiAc() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => GirisSayfasi(
          onGiris: () async {
            if (Navigator.of(routeContext).canPop()) {
              Navigator.of(routeContext).pop();
            }
          },
        ),
      ),
    );
    await _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('GİRİŞ GÜVENLİĞİ')),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: SwitchListTile(
                    value: true,
                    onChanged: null,
                    secondary: const Icon(Icons.verified_user_rounded),
                    title: const Text('E-posta / Şifre Girişi Zorunlu'),
                    subtitle: Text(
                      user == null
                          ? 'Güvenlik nedeniyle giriş kapatılamaz.'
                          : 'Giriş güvenliği açık • Bağlı hesap: ${user.email ?? user.id}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (user == null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Icon(Icons.login_rounded, size: 42),
                          const SizedBox(height: 10),
                          const Text(
                            'Güvenli girişi açmak için önce yönetici hesabınızla giriş yapın.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _yoneticiGirisiAc,
                            icon: const Icon(Icons.verified_user_rounded),
                            label: const Text('Yönetici Hesabıyla Giriş Yap'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: KimlikDogrulamaService.cikisYap,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Bu Hesaptan Çıkış Yap'),
                  ),
              ],
            ),
    );
  }
}
