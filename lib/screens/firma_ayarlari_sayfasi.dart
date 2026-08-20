import 'package:flutter/material.dart';

import '../services/firma_ayarlari_service.dart';

class FirmaAyarlariSayfasi extends StatefulWidget {
  const FirmaAyarlariSayfasi({super.key});

  @override
  State<FirmaAyarlariSayfasi> createState() =>
      _FirmaAyarlariSayfasiState();
}

class _FirmaAyarlariSayfasiState extends State<FirmaAyarlariSayfasi> {
  final _unvan = TextEditingController();
  final _adres = TextEditingController();
  final _il = TextEditingController();
  final _ilce = TextEditingController();
  final _telefon = TextEditingController();
  final _eposta = TextEditingController();
  final _vergiDairesi = TextEditingController();
  final _vergiNo = TextEditingController();
  final _iban = TextEditingController();
  final _logoUrl = TextEditingController();

  bool _yukleniyor = true;
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    for (final c in [
      _unvan,
      _adres,
      _il,
      _ilce,
      _telefon,
      _eposta,
      _vergiDairesi,
      _vergiNo,
      _iban,
      _logoUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _yukle() async {
    final ayar = await FirmaAyarlariService.getir(zorla: true);
    if (!mounted) return;
    _unvan.text = ayar.unvan;
    _adres.text = ayar.adres;
    _il.text = ayar.il;
    _ilce.text = ayar.ilce;
    _telefon.text = ayar.telefon;
    _eposta.text = ayar.eposta;
    _vergiDairesi.text = ayar.vergiDairesi;
    _vergiNo.text = ayar.vergiNo;
    _iban.text = ayar.iban;
    _logoUrl.text = ayar.logoUrl;
    setState(() => _yukleniyor = false);
  }

  Future<void> _kaydet() async {
    if (_unvan.text.trim().isEmpty) {
      _mesaj('Firma ünvanı boş bırakılamaz.', Colors.red);
      return;
    }

    setState(() => _kaydediliyor = true);
    try {
      await FirmaAyarlariService.kaydet(
        FirmaAyarlari(
          unvan: _unvan.text,
          adres: _adres.text,
          il: _il.text,
          ilce: _ilce.text,
          telefon: _telefon.text,
          eposta: _eposta.text,
          vergiDairesi: _vergiDairesi.text,
          vergiNo: _vergiNo.text,
          iban: _iban.text,
          logoUrl: _logoUrl.text,
        ),
      );
      if (!mounted) return;
      _mesaj('Firma ve çıktı bilgileri kaydedildi.', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _mesaj('Firma ayarları kaydedilemedi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  void _mesaj(String mesaj, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), backgroundColor: renk),
    );
  }

  Widget _alan(
    TextEditingController controller,
    String etiket, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: etiket,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FİRMA / ÇIKTI AYARLARI'),
        actions: [
          ElevatedButton.icon(
            onPressed: _kaydediliyor ? null : _kaydet,
            icon: const Icon(Icons.save_rounded),
            label: Text(_kaydediliyor ? 'Kaydediliyor...' : 'Kaydet'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text(
                  'Bu bilgiler müşteri faturası, irsaliye ve cari ekstre '
                  'çıktılarında kullanılacaktır.',
                ),
                const SizedBox(height: 16),
                _alan(_unvan, 'Firma Ünvanı'),
                const SizedBox(height: 12),
                _alan(_adres, 'Adres', maxLines: 2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _alan(_il, 'İl')),
                    const SizedBox(width: 12),
                    Expanded(child: _alan(_ilce, 'İlçe')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _alan(_telefon, 'Telefon')),
                    const SizedBox(width: 12),
                    Expanded(child: _alan(_eposta, 'E-posta')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _alan(_vergiDairesi, 'Vergi Dairesi')),
                    const SizedBox(width: 12),
                    Expanded(child: _alan(_vergiNo, 'Vergi / T.C. No')),
                  ],
                ),
                const SizedBox(height: 12),
                _alan(_iban, 'IBAN'),
                const SizedBox(height: 12),
                _alan(_logoUrl, 'Logo URL (isteğe bağlı)'),
              ],
            ),
    );
  }
}
