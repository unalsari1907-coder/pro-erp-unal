import 'package:flutter/material.dart';

import '../services/kimlik_dogrulama_service.dart';

class GirisSayfasi extends StatefulWidget {
  final Future<void> Function()? onGiris;

  const GirisSayfasi({super.key, this.onGiris});

  @override
  State<GirisSayfasi> createState() => _GirisSayfasiState();
}

class _GirisSayfasiState extends State<GirisSayfasi> {
  final _eposta = TextEditingController();
  final _sifre = TextEditingController();
  bool _calisiyor = false;
  bool _sifreGizli = true;

  @override
  void dispose() {
    _eposta.dispose();
    _sifre.dispose();
    super.dispose();
  }

  Future<void> _giris() async {
    if (_eposta.text.trim().isEmpty || _sifre.text.isEmpty) return;
    setState(() => _calisiyor = true);
    try {
      await KimlikDogrulamaService.girisYap(_eposta.text, _sifre.text);
      await widget.onGiris?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hataMesaji(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  String _hataMesaji(Object hata) {
    final metin = hata.toString().toLowerCase();
    if (metin.contains('invalid login credentials') ||
        metin.contains('invalid_credentials')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (metin.contains('email not confirmed') ||
        metin.contains('email_not_confirmed')) {
      return 'E-posta hesabı henüz doğrulanmamış.';
    }
    if (metin.contains('network') || metin.contains('socket')) {
      return 'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edin.';
    }
    return 'Giriş yapılamadı. Lütfen bilgilerinizi kontrol edip tekrar deneyin.';
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MediaQuery.sizeOf(context).width < 500;

    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: EdgeInsets.all(mobil ? 20 : 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_rounded, size: 56, color: Colors.blue),
                  const SizedBox(height: 10),
                  const Text('ÜNAL YEDEK PARÇA ERP',
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                  const Text('Güvenli kullanıcı girişi'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _eposta,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sifre,
                    obscureText: _sifreGizli,
                    onSubmitted: (_) => _giris(),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _sifreGizli = !_sifreGizli),
                        icon: Icon(_sifreGizli ? Icons.visibility : Icons.visibility_off),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _calisiyor ? null : _giris,
                      icon: const Icon(Icons.login_rounded),
                      label: Text(_calisiyor ? 'Giriş yapılıyor...' : 'Giriş Yap'),
                    ),
                  ),
                ],
              ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
